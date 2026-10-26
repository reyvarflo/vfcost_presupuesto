import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formula_polinomica.dart';
import '../providers/presupuesto_provider.dart';
import '../services/formula_service.dart';

class FormulaGroupingScreen extends StatefulWidget {
  const FormulaGroupingScreen({super.key});

  @override
  State<FormulaGroupingScreen> createState() => _FormulaGroupingScreenState();
}

class _FormulaGroupingScreenState extends State<FormulaGroupingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, int> _asignaciones = {};
  final Map<int, String> _simbolos = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final provider = context.read<PresupuestoProvider>();
      final p = provider.activePresupuesto;
      if (p != null) {
        // Cargar asignaciones existentes de la fórmula guardada o sugerir
        if (p.formulaPolinomica.monomios.isNotEmpty) {
          for (final m in p.formulaPolinomica.monomios) {
            _simbolos[m.monomioNumber] = m.symbol;
            for (final sub in m.submonomios) {
              _asignaciones[sub.unifiedIndex] = m.monomioNumber;
            }
          }
        } else {
          _asignaciones.addAll(FormulaService.sugerirAgrupamiento(p));
        }
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final p = provider.activePresupuesto;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agrupamiento Polinómico')),
        body: const Center(child: Text('No hay presupuesto activo')),
      );
    }

    final resumenIUs = FormulaService.obtenerResumenIUs(
      p,
      asignaciones: _asignaciones,
      simbolos: _simbolos,
    );

    final formulaCalculada = FormulaService.construirFormulaPersonalizada(
      p,
      _asignaciones,
      simbolosMonomio: _simbolos,
    );

    final sumaK = formulaCalculada.sumaCoeficientes;
    final numMonomios = formulaCalculada.monomios.length;
    final isValid = formulaCalculada.isValid && numMonomios <= 8;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agrupamiento de Datos e IUs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: '1. Agrupar IUs'),
            Tab(icon: Icon(Icons.calculate_outlined), text: '2. Monomios y K'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Sugerir Agrupamiento Normativo (D.S. 011-79-VC)',
            onPressed: () {
              setState(() {
                _asignaciones.clear();
                _asignaciones.addAll(FormulaService.sugerirAgrupamiento(p));
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agrupamiento normativo D.S. N° 011-79-VC aplicado'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar Fórmula',
            onPressed: () => _guardarFormula(provider, formulaCalculada),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Validación Normativa en tiempo real
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isValid ? Colors.green.shade50 : Colors.amber.shade50,
            child: Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isValid ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monomios: $numMonomios de 8 máx | Σk = ${sumaK.toStringAsFixed(3)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isValid ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        numMonomios > 8
                            ? 'Excede los 8 monomios permitidos por norma.'
                            : (sumaK - 1.0).abs() > 0.005
                                ? 'La suma de coeficientes debe ser 1.000.'
                                : 'Cumple los requisitos normativos del D.S. N° 011-79-VC.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isValid ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _guardarFormula(provider, formulaCalculada),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aplicar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // PESTAÑA 1: LISTADO DE IUs PARA SELECCIONAR Y AGRUPAR
                _buildIuListTab(resumenIUs, p),

                // PESTAÑA 2: VISTA PREVIA Y EDICIÓN DE MONOMIOS
                _buildMonomiosPreviewTab(formulaCalculada),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIuListTab(List<IuResumen> ius, dynamic p) {
    if (ius.isEmpty) {
      return const Center(child: Text('No hay insumos registrados en el presupuesto'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ius.length,
      itemBuilder: (context, index) {
        final iu = ius[index];
        final porcentaje = (iu.incidencia * 100);
        final esMayorCinco = porcentaje >= 5.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: esMayorCinco ? Colors.blue.shade200 : Colors.amber.shade300,
              width: esMayorCinco ? 1 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge del IU
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'IU ${iu.iu.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            iu.descripcion,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Costo: ${p.currencySymbol} ${iu.costo.toStringAsFixed(2)} | Incidencia: ${porcentaje.toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    // Etiqueta 5%
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: esMayorCinco ? Colors.green.shade100 : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        esMayorCinco ? '≥ 5%' : '< 5% (Agrupar)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: esMayorCinco ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Selector de Monomio Asignado
                Row(
                  children: [
                    const Text(
                      'Agrupar en Monomio:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _asignaciones[iu.iu] ?? iu.monomioAsignado,
                            isDense: true,
                            items: List.generate(8, (i) {
                              final mNum = i + 1;
                              final sim = _simbolos[mNum] ?? '';
                              return DropdownMenuItem<int>(
                                value: mNum,
                                child: Text(
                                  'Monomio $mNum ${sim.isNotEmpty ? "($sim)" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }),
                            onChanged: (newMonomio) {
                              if (newMonomio != null) {
                                setState(() {
                                  _asignaciones[iu.iu] = newMonomio;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonomiosPreviewTab(FormulaPolinomica formula) {
    final monomios = formula.monomios;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expresión K resultante
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fórmula Polinómica Resultante (K)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatFormulaString(monomios),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Desglose de Monomios Conformados (${monomios.length} de 8)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...monomios.map((m) {
            final cumpleIncidencia = m.coeficiente >= 0.050;
            final maxSubmonomios = m.submonomios.length <= 3;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: cumpleIncidencia && maxSubmonomios
                      ? Colors.grey.shade300
                      : Colors.amber.shade400,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Número de Monomio y Símbolo editable
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Monomio ${m.monomioNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              height: 32,
                              child: TextField(
                                controller: TextEditingController(text: m.symbol)
                                  ..selection = TextSelection.collapsed(offset: m.symbol.length),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (val) {
                                  _simbolos[m.monomioNumber] = val.trim();
                                },
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'k = ${m.coeficiente.toStringAsFixed(3)} (${(m.coeficiente * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!cumpleIncidencia)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '⚠️ Advertencia: Coeficiente k < 0.050 (Norma D.S. N° 011-79-VC exige ≥ 5%)',
                          style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900),
                        ),
                      ),
                    if (!maxSubmonomios)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠️ Advertencia: Tiene más de 3 submonomios (máx 3 permitidos)',
                          style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900),
                        ),
                      ),
                    const Divider(height: 16),
                    ...m.submonomios.map((sub) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, size: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'IU ${sub.unifiedIndex.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sub.description,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Factor: ${sub.factor.toStringAsFixed(3)} (${(sub.factor * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatFormulaString(List<Monomio> monomios) {
    if (monomios.isEmpty) return 'K = 1.000';
    final parts = <String>[];
    for (final m in monomios) {
      final sym = m.symbol;
      final k = m.coeficiente.toStringAsFixed(3);
      if (m.submonomios.length <= 1) {
        parts.add('$k * (${sym}_r / ${sym}_o)');
      } else {
        final subParts = m.submonomios.map((s) {
          final f = s.factor.toStringAsFixed(3);
          final iu = s.unifiedIndex.toString().padLeft(2, '0');
          return '$f*(I${iu}_r/I${iu}_o)';
        }).join(' + ');
        parts.add('$k * [$subParts]');
      }
    }
    return 'K = ${parts.join(' +\n    ')}';
  }

  void _guardarFormula(PresupuestoProvider provider, FormulaPolinomica formula) {
    provider.updateFormulaPolinomica(formula);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Fórmula Polinómica guardada y actualizada en el presupuesto'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}
