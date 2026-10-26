import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/apu_item.dart';
import '../models/metrado_line.dart';
import '../models/partida.dart';
import '../models/resource.dart';
import '../providers/presupuesto_provider.dart';
import '../utils/number_format_utils.dart';
import '../widgets/apu_resource_dialog.dart';

class ApuEditorScreen extends StatefulWidget {
  final Partida partida;
  final int initialBottomTab; // 0=Análisis C.U, 1=Especif. técnicas, 2=Metrado, 3=Metrado Fierro, 4=Consol. Partida

  const ApuEditorScreen({
    super.key,
    required this.partida,
    this.initialBottomTab = 0,
  });

  @override
  State<ApuEditorScreen> createState() => _ApuEditorScreenState();
}

class _ApuEditorScreenState extends State<ApuEditorScreen> {
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  final _qtyFormat = NumberFormat('#,##0.0000', 'es_PE');
  final _durFormat = NumberFormat('0.000', 'es_PE');

  late TextEditingController _rendimientoController;
  late TextEditingController _metradoController;
  late TextEditingController _espDescController;
  late TextEditingController _espMedicionController;
  late TextEditingController _espPagoController;

  late Partida _localPartida;
  late int _activeBottomTab;
  bool _incluirPieEnAcu = false; // Botón "ACU (Inc. Pie Presupuesto)" de Delphin

  @override
  void initState() {
    super.initState();
    _localPartida = widget.partida;
    _activeBottomTab = widget.initialBottomTab;
    _rendimientoController = TextEditingController(text: _localPartida.rendimiento.toStringAsFixed(2));
    _metradoController = TextEditingController(text: _localPartida.metradoEfectivo.toStringAsFixed(2));
    _espDescController = TextEditingController(text: _localPartida.effectiveEspecificacionDescripcion);
    _espMedicionController = TextEditingController(text: _localPartida.effectiveEspecificacionMedicion);
    _espPagoController = TextEditingController(text: _localPartida.effectiveEspecificacionPago);
  }

  @override
  void dispose() {
    _rendimientoController.dispose();
    _metradoController.dispose();
    _espDescController.dispose();
    _espMedicionController.dispose();
    _espPagoController.dispose();
    super.dispose();
  }

  void _onRendimientoChanged(String val, double jornada) {
    final rdto = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    if (rdto > 0) {
      final updated = _localPartida.copyWith(rendimiento: rdto).recalculateWithJornada(jornada);
      setState(() {
        _localPartida = updated;
      });
      context.read<PresupuestoProvider>().updatePartida(updated);
    }
  }

  void _onMetradoChanged(String val) {
    final metrado = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    final updated = _localPartida.copyWith(
      metrado: metrado,
      costoParcial: metrado * _localPartida.calculateUnitPrice(),
    );
    setState(() {
      _localPartida = updated;
    });
    context.read<PresupuestoProvider>().updatePartida(updated);
  }

  void _saveEspecificaciones() {
    final updated = _localPartida.copyWith(
      especificacionDescripcion: _espDescController.text.trim(),
      especificacionMedicion: _espMedicionController.text.trim(),
      especificacionPago: _espPagoController.text.trim(),
    );
    setState(() => _localPartida = updated);
    context.read<PresupuestoProvider>().updatePartida(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Especificación técnica guardada en la partida.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _editDesperdicio(ApuItem item, double jornada) {
    final ctrl = TextEditingController(text: item.desperdicio.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('% Desperdicio de Material (Delphin)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.resourceDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Porcentaje de Desperdicio (%)',
                suffixText: '%',
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
              final desp = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
              final updatedItem = item.copyWith(desperdicio: desp.clamp(0.0, 100.0));
              context.read<PresupuestoProvider>().updateApuItem(_localPartida.id, updatedItem);
              setState(() {
                final updatedList = _localPartida.apuItems.map((a) => a.id == updatedItem.id ? updatedItem : a).toList();
                _localPartida = _localPartida.copyWith(apuItems: updatedList).recalculateWithJornada(jornada);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _addResource(BuildContext context, double jornada) {
    final provider = context.read<PresupuestoProvider>();
    showDialog(
      context: context,
      builder: (ctx) => ApuResourceDialog(
        masterCatalog: provider.masterResources,
        rendimiento: _localPartida.rendimiento,
        jornada: jornada,
        subtotalMO: _localPartida.subtotalMO,
        currencySymbol: provider.activePresupuesto?.currencySymbol ?? 'S/.',
        onSave: (item) {
          provider.addApuItem(_localPartida.id, item);
          setState(() {
            final updatedList = List<ApuItem>.from(_localPartida.apuItems)..add(item);
            _localPartida = _localPartida.copyWith(apuItems: updatedList).recalculateWithJornada(jornada);
          });
        },
      ),
    );
  }

  void _editResource(BuildContext context, ApuItem item, double jornada) {
    final provider = context.read<PresupuestoProvider>();
    showDialog(
      context: context,
      builder: (ctx) => ApuResourceDialog(
        existingItem: item,
        masterCatalog: provider.masterResources,
        rendimiento: _localPartida.rendimiento,
        jornada: jornada,
        subtotalMO: _localPartida.subtotalMO,
        currencySymbol: provider.activePresupuesto?.currencySymbol ?? 'S/.',
        onSave: (updated) {
          provider.updateApuItem(_localPartida.id, updated);
          setState(() {
            final updatedList = _localPartida.apuItems.map((a) => a.id == updated.id ? updated : a).toList();
            _localPartida = _localPartida.copyWith(apuItems: updatedList).recalculateWithJornada(jornada);
          });
        },
      ),
    );
  }

  void _deleteResource(String itemId, double jornada) {
    final provider = context.read<PresupuestoProvider>();
    provider.removeApuItem(_localPartida.id, itemId);
    setState(() {
      final updatedList = _localPartida.apuItems.where((a) => a.id != itemId).toList();
      _localPartida = _localPartida.copyWith(apuItems: updatedList).recalculateWithJornada(jornada);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;
    final sub = provider.activeSubpresupuesto;
    final jornada = presupuesto?.jornada ?? 8.0;
    final currency = presupuesto?.currencySymbol ?? 'S/.';

    // Sincronizar con el provider
    final currentFromProvider = sub?.partidas
        .firstWhere((p) => p.id == _localPartida.id, orElse: () => _localPartida);
    if (currentFromProvider != null) {
      _localPartida = currentFromProvider;
    }

    // Factor de Pie de Presupuesto si el botón "ACU (Inc. Pie Presupuesto)" está activo
    double factorPie = 1.0;
    if (_incluirPieEnAcu && presupuesto != null && presupuesto.totalCostoDirecto > 0) {
      factorPie = presupuesto.subtotal / presupuesto.totalCostoDirecto;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_localPartida.itemNumber} ${_localPartida.description}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Presupuesto: ${sub?.name.toUpperCase() ?? "ESTRUCTURA"}  •  Unidad: ${_localPartida.unit}',
              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_activeBottomTab == 0)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Agregar Insumo al APU',
              onPressed: () => _addResource(context, jornada),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _activeBottomTab,
              children: [
                _buildTabAnalisisCU(context, jornada, currency, factorPie, sub?.name ?? 'ESTRUCTURA', presupuesto?.date),
                _buildTabEspecificacionesTecnicas(context, sub?.name ?? 'ESTRUCTURA'),
                _buildTabMetradoClasico(context, sub?.name ?? 'ESTRUCTURA', isAceroMode: false),
                _buildTabMetradoClasico(context, sub?.name ?? 'ESTRUCTURA', isAceroMode: true),
                _buildTabConsolidadoPartida(context, currency),
              ],
            ),
          ),

          // Barra de Pestañas Inferior Estilo Delphin Express BIM 360:
          // [Análisis de C.U] | [Especif. técnicas] | [Metrado] | [Metrado Xls (Fierro)] | [Σ Consol. de Partida]
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFDCE6F2),
              border: Border(top: BorderSide(color: Color(0xFF94A3B8))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              children: [
                _buildBottomDelphinTab(
                  index: 0,
                  icon: Icons.analytics_outlined,
                  iconColor: Colors.orange.shade800,
                  label: 'Análisis de C.U',
                ),
                _buildBottomDelphinTab(
                  index: 1,
                  icon: Icons.description_outlined,
                  iconColor: Colors.blue.shade800,
                  label: 'Especif. técnicas',
                ),
                _buildBottomDelphinTab(
                  index: 2,
                  icon: Icons.straighten_outlined,
                  iconColor: Colors.amber.shade900,
                  label: 'Metrado',
                ),
                _buildBottomDelphinTab(
                  index: 3,
                  icon: Icons.grid_on_outlined,
                  iconColor: Colors.green.shade800,
                  label: 'Metrado Fierro / Xls',
                ),
                _buildBottomDelphinTab(
                  index: 4,
                  icon: Icons.functions,
                  iconColor: Colors.purple.shade800,
                  label: 'Consol. de Partida',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDelphinTab({
    required int index,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    final selected = _activeBottomTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () => setState(() => _activeBottomTab = index),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: ANÁLISIS DE COSTO UNITARIO (Imagen 1 de Delphin)
  // ===========================================================================
  Widget _buildTabAnalisisCU(
    BuildContext context,
    double jornada,
    String currency,
    double factorPie,
    String subName,
    DateTime? projDate,
  ) {
    final moItems = _localPartida.apuItems.where((i) => i.type == ResourceType.manoDeObra).toList();
    final matItems = _localPartida.apuItems.where((i) => i.type == ResourceType.material).toList();
    final eqItems = _localPartida.apuItems.where((i) => i.type == ResourceType.equipo).toList();
    final scItems = _localPartida.apuItems.where((i) => i.type == ResourceType.subcontrato).toList();

    final unitPrice = _localPartida.calculateUnitPrice() * factorPie;
    final duracionExacta = _localPartida.duracionExactaDias;
    final dateStr = DateFormat('dd/MM/yyyy').format(projDate ?? DateTime.now());

    return Column(
      children: [
        // 1. Cabecera Azul Claro de Delphin con recuadro "DURACIÓN FIJA programada para ejecutar"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Análisis de costo unitario',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Presupuesto:   ${subName.toUpperCase()}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                    Text(
                      '${_localPartida.itemNumber}     ${_localPartida.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Recuadro de Duración Fija Programada estilo Delphin
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2F8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF94A3B8)),
                ),
                child: Column(
                  children: [
                    Text(
                      'DURACIÓN FIJA\nprogramada para ejecutar\n${_currencyFormat.format(_localPartida.metradoEfectivo)} ${_localPartida.unit}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blueGrey.shade300),
                      ),
                      child: Text(
                        '${_durFormat.format(duracionExacta)} días',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Barra de Rendimiento Diario (fondo amarillo) y Jornada
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFEDF2F8),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_box, size: 16, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 4),
                  Text('Por Rendimiento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rend. diario: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: 74,
                    height: 26,
                    child: TextField(
                      controller: _rendimientoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFEF08A), // Amarillo Delphin
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
                      ),
                      onChanged: (v) => _onRendimientoChanged(v, jornada),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueGrey.shade300),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _localPartida.unit,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Jornada: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueGrey.shade300),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${jornada.toStringAsFixed(2)} h/día',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. Encabezados de Columna de la Cuadrícula del APU (Imagen 1):
        //    Descripción | Nro. Rec. | Cantidad | % Desp. | Precio | Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 48,
                child: Text('Nro. Rec.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 78,
                child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 44,
                child: Text('% Desp.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 58,
                child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 64,
                child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 28),
            ],
          ),
        ),

        // 4. Filas del APU agrupadas por MANO DE OBRA, MATERIALES, EQUIPO, SUB-CONTRATOS, SUB PARTIDAS
        Expanded(
          child: ListView(
            children: [
              _buildDelphinApuSection(
                title: 'MANO DE OBRA',
                items: moItems,
                subtotal: _localPartida.subtotalMO * factorPie,
                factorPie: factorPie,
                jornada: jornada,
              ),
              _buildDelphinApuSection(
                title: 'MATERIALES',
                items: matItems,
                subtotal: _localPartida.subtotalMateriales * factorPie,
                factorPie: factorPie,
                jornada: jornada,
                showDesperdicio: true,
              ),
              _buildDelphinApuSection(
                title: 'EQUIPO',
                items: eqItems,
                subtotal: _localPartida.subtotalEquipos * factorPie,
                factorPie: factorPie,
                jornada: jornada,
              ),
              _buildDelphinApuSection(
                title: 'SUB-CONTRATOS',
                items: scItems,
                subtotal: _localPartida.subtotalSubcontratos * factorPie,
                factorPie: factorPie,
                jornada: jornada,
              ),
              _buildDelphinApuSection(
                title: 'SUB PARTIDAS',
                items: const [],
                subtotal: 0.0,
                factorPie: factorPie,
                jornada: jornada,
              ),
            ],
          ),
        ),

        // 5. Pie del APU con Costo Total y botón "ACU (Inc. Pie Presupuesto)"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(top: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parcial Partida (${NumberFormatUtils.formatNumber(_localPartida.metradoEfectivo)} ${_localPartida.unit}): ${NumberFormatUtils.formatCurrency(unitPrice * _localPartida.metradoEfectivo, symbol: currency)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Costo total:   ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        NumberFormatUtils.formatCurrency(unitPrice, symbol: currency),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fecha: $dateStr     Hecho por: Administrador',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                  InkWell(
                    onTap: () => setState(() => _incluirPieEnAcu = !_incluirPieEnAcu),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _incluirPieEnAcu ? const Color(0xFF1E3A8A) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF64748B)),
                      ),
                      child: Text(
                        'ACU (Inc. Pie Presupuesto)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _incluirPieEnAcu ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDelphinApuSection({
    required String title,
    required List<ApuItem> items,
    required double subtotal,
    required double factorPie,
    required double jornada,
    bool showDesperdicio = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera del grupo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            color: Color(0xFFEAF1F8),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    items.isNotEmpty ? Icons.keyboard_arrow_down : Icons.remove,
                    size: 15,
                    color: const Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Text(
                  NumberFormatUtils.formatNumber(subtotal),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
        // Filas de recursos
        ...items.map((item) {
          final iuStr = (item.unifiedIndex > 0 ? item.unifiedIndex : 39).toString().padLeft(2, '0');
          final parcial = item.calculateParcial(subtotalMO: _localPartida.subtotalMO) * factorPie;
          final precio = item.isPercentageOfMO
              ? _localPartida.subtotalMO * factorPie
              : item.precioUnitario * factorPie;

          return InkWell(
            onTap: () => _editResource(context, item, jornada),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.7)),
              ),
              child: Row(
                children: [
                  // IU + Descripción (ej: "47 OPERARIO", "21 CEMENTO PORTLAND TIPO I")
                  Expanded(
                    flex: 5,
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A)),
                        children: [
                          TextSpan(
                            text: '$iuStr ',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: item.resourceDescription,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Nro. Rec. (Cuadrilla)
                  SizedBox(
                    width: 48,
                    child: Text(
                      item.cuadrilla > 0 ? item.cuadrilla.toStringAsFixed(2) : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                  // Cantidad + unidad en azul
                  SizedBox(
                    width: 78,
                    child: RichText(
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 10, color: Color(0xFF0F172A)),
                        children: [
                          TextSpan(
                            text: item.isPercentageOfMO
                                ? '${item.percentageValue.toStringAsFixed(4)} '
                                : '${_qtyFormat.format(item.cantidad)} ',
                          ),
                          TextSpan(
                            text: item.isPercentageOfMO ? '%mo' : item.unit,
                            style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // % Desp. (Tocar para editar el desperdicio en materiales)
                  SizedBox(
                    width: 44,
                    child: showDesperdicio
                        ? InkWell(
                            onTap: () => _editDesperdicio(item, jornada),
                            child: Text(
                              '${item.desperdicio.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.desperdicio > 0 ? Colors.red.shade700 : const Color(0xFF334155),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Precio
                  SizedBox(
                    width: 58,
                    child: Text(
                      NumberFormatUtils.formatNumber(precio),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                  // Total
                  SizedBox(
                    width: 64,
                    child: Text(
                      NumberFormatUtils.formatNumber(parcial),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Eliminar
                  SizedBox(
                    width: 28,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar insumo',
                      onPressed: () => _deleteResource(item.id, jornada),
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

  // ===========================================================================
  // PESTAÑA 2: ESPECIFICACIONES TÉCNICAS (Imagen 9 de Delphin)
  // ===========================================================================
  Widget _buildTabEspecificacionesTecnicas(BuildContext context, String subName) {
    return Column(
      children: [
        // Cabecera de Especificaciones Técnicas con botones Word / PDF / Guardar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Especificaciones técnicas',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Presupuesto: ${subName.toUpperCase()}  •  ${_localPartida.itemNumber} ${_localPartida.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all, size: 18, color: Color(0xFF1E3A8A)),
                tooltip: 'Copiar especificación técnica completa',
                onPressed: () {
                  final fullText = '${_localPartida.itemNumber} ${_localPartida.description} (Unidad: ${_localPartida.unit})\n\n'
                      'Descripción y Método de construcción:\n${_espDescController.text}\n\n'
                      'Método de medición:\n${_espMedicionController.text}\n\n'
                      'Bases de pago:\n${_espPagoController.text}';
                  Clipboard.setData(ClipboardData(text: fullText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Especificación técnica copiada al portapapeles.')),
                  );
                },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.save, size: 15),
                label: const Text('Guardar', style: TextStyle(fontSize: 11.5)),
                onPressed: _saveEspecificaciones,
              ),
            ],
          ),
        ),

        // Hoja tipo documento A4 centrada (como en la Imagen 9 de Delphin)
        Expanded(
          child: Container(
            color: const Color(0xFFCBD5E1),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                            children: [
                              TextSpan(
                                text: '${_localPartida.itemNumber}  ${_localPartida.description.toUpperCase()}  ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '(Unidad de medida: ${_localPartida.unit})',
                                style: const TextStyle(color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 20),
                        const Text(
                          'Descripción y Método de construcción:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _espDescController,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Método de medición:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _espMedicionController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Bases de pago:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _espPagoController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑAS 3 Y 4: METRADO CLÁSICO Y METRADO DE FIERRO / ACERO (Imagen 10)
  // ===========================================================================
  Widget _buildTabMetradoClasico(BuildContext context, String subName, {required bool isAceroMode}) {
    final lines = _localPartida.metradoLines;
    final totalHoja = lines.fold(0.0, (s, l) => s + l.parcial);

    return Column(
      children: [
        // Cabecera estilo hoja de cálculo Delphin
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAceroMode ? 'Metrado de Fierro y Acero (ASTM A615)' : 'Metrado (Hoja de Sustento)',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${_localPartida.itemNumber} ${_localPartida.description}  •  Total: ${_currencyFormat.format(totalHoja)} ${_localPartida.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.add, size: 15),
                label: Text(isAceroMode ? 'Agregar Fierro' : 'Agregar Fila', style: const TextStyle(fontSize: 11.5)),
                onPressed: () => _openAddMetradoLineDialog(isAceroMode: isAceroMode),
              ),
            ],
          ),
        ),

        // Encabezado de columnas A..H como en la Imagen 10 de Delphin:
        // Descripción | Elementos | Cant. x Elem. | Largo | Ancho/Ø | Alto/kg/m | Parcial | Plano - Referencia
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text('Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(
                width: 48,
                child: Text('Elem.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(
                width: 52,
                child: Text('Cant.xEl.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(
                width: 52,
                child: Text('Largo', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  isAceroMode ? 'Diám. Ø' : 'Ancho',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  isAceroMode ? 'kg/m' : 'Alto',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(
                width: 66,
                child: Text('Parcial', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
              const Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('Plano - Ref.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 26),
            ],
          ),
        ),

        // Filas de la planilla
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_rows_outlined, size: 42, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        isAceroMode
                            ? 'Agregue filas de acero corrugado por diámetro (3/8", 1/2", 5/8", 3/4", 1")'
                            : 'Agregue filas de sustento de metrados (Elementos × Cant.xElem × Largo × Ancho × Alto)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (ctx, idx) {
                    final l = lines[idx];
                    final pesoNominal = l.diametroAcero != null
                        ? MetradoLine.pesosAceroKgPorMetro[l.diametroAcero!]
                        : null;

                    return InkWell(
                      onTap: () => _openAddMetradoLineDialog(
                        existing: l,
                        index: idx,
                        isAceroMode: l.diametroAcero != null || isAceroMode,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.7)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                l.descripcion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(_currencyFormat.format(l.veces), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(_currencyFormat.format(l.cantidadPorElemento), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(l.largo != null ? _currencyFormat.format(l.largo) : '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                l.diametroAcero ?? (l.ancho != null ? _currencyFormat.format(l.ancho) : '-'),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: l.diametroAcero != null ? FontWeight.bold : FontWeight.normal,
                                  color: l.diametroAcero != null ? const Color(0xFF1E3A8A) : Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                pesoNominal != null
                                    ? pesoNominal.toStringAsFixed(3)
                                    : (l.alto != null ? _currencyFormat.format(l.alto) : '-'),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                            SizedBox(
                              width: 66,
                              child: Text(
                                _currencyFormat.format(l.parcial),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  l.planoReferencia,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 26,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final updatedLines = List<MetradoLine>.from(lines)..removeAt(idx);
                                  context.read<PresupuestoProvider>().updatePartidaMetrados(_localPartida.id, updatedLines);
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

        // Fila Total al pie de la hoja de metrados
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFEDF2F8),
            border: Border(top: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${lines.length} filas en planilla',
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
              Row(
                children: [
                  const Text('Total:   ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_currencyFormat.format(totalHoja)} ${_localPartida.unit}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddMetradoLineDialog({MetradoLine? existing, int? index, required bool isAceroMode}) {
    final descCtrl = TextEditingController(text: existing?.descripcion ?? '');
    final elemCtrl = TextEditingController(text: (existing?.veces ?? 1.0).toString());
    final cantElemCtrl = TextEditingController(text: (existing?.cantidadPorElemento ?? 1.0).toString());
    final largoCtrl = TextEditingController(text: (existing?.largo ?? 1.0).toString());
    final anchoCtrl = TextEditingController(text: existing?.ancho?.toString() ?? '');
    final altoCtrl = TextEditingController(text: existing?.alto?.toString() ?? '');
    final planoCtrl = TextEditingController(text: existing?.planoReferencia ?? '');
    String selectedDiam = existing?.diametroAcero ?? '1/2"';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            isAceroMode ? 'Línea de Metrado de Acero (kg)' : 'Línea de Hoja de Metrado (Delphin)',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Elemento / Eje',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: elemCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Elementos',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cantElemCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cant. x Elem.',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isAceroMode)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDiam,
                          decoration: const InputDecoration(
                            labelText: 'Diámetro Ø',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: MetradoLine.pesosAceroKgPorMetro.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text('${e.key} (${e.value} kg/m)', style: const TextStyle(fontSize: 11.5)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => selectedDiam = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: largoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Longitud (m)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: largoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Largo (m)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: anchoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Ancho (m)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: altoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Alto (m)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: planoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Plano - Referencia (ej. E-01, L-02)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final newLine = MetradoLine(
                  id: existing?.id ?? _uuid.v4(),
                  descripcion: descCtrl.text.trim().isEmpty ? 'Tramo / Eje' : descCtrl.text.trim(),
                  veces: double.tryParse(elemCtrl.text.replaceAll(',', '.')) ?? 1.0,
                  cantidadPorElemento: double.tryParse(cantElemCtrl.text.replaceAll(',', '.')) ?? 1.0,
                  largo: double.tryParse(largoCtrl.text.replaceAll(',', '.')),
                  ancho: isAceroMode ? null : double.tryParse(anchoCtrl.text.replaceAll(',', '.')),
                  alto: isAceroMode ? null : double.tryParse(altoCtrl.text.replaceAll(',', '.')),
                  planoReferencia: planoCtrl.text.trim(),
                  diametroAcero: isAceroMode ? selectedDiam : null,
                );

                final updatedLines = List<MetradoLine>.from(_localPartida.metradoLines);
                if (index != null && index >= 0) {
                  updatedLines[index] = newLine;
                } else {
                  updatedLines.add(newLine);
                }

                context.read<PresupuestoProvider>().updatePartidaMetrados(_localPartida.id, updatedLines);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 5: CONSOLIDADO DE PARTIDA (Σ Consol. de Partida)
  // ===========================================================================
  Widget _buildTabConsolidadoPartida(BuildContext context, String currency) {
    final m = _localPartida.metradoEfectivo;
    final moTotal = _localPartida.costoManoObraTotal;
    final matTotal = _localPartida.costoMaterialesTotal;
    final eqTotal = _localPartida.costoEquiposTotal;
    final scTotal = _localPartida.costoSubcontratosTotal;
    final totalPartida = moTotal + matTotal + eqTotal + scTotal;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consolidado Total para Ejecutar ${_currencyFormat.format(m)} ${_localPartida.unit}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const Divider(height: 18),
                _buildConsolRow('Mano de Obra Total', '$currency ${_currencyFormat.format(moTotal)}'),
                _buildConsolRow('Materiales Total', '$currency ${_currencyFormat.format(matTotal)}'),
                _buildConsolRow('Equipos y Herramientas Total', '$currency ${_currencyFormat.format(eqTotal)}'),
                _buildConsolRow('Sub-Contratos Total', '$currency ${_currencyFormat.format(scTotal)}'),
                const Divider(height: 18),
                _buildConsolRow('COSTO DIRECTO TOTAL DE LA PARTIDA', '$currency ${_currencyFormat.format(totalPartida)}', isBold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Requerimiento Total de Insumos en esta Partida (Cantidad Unitaria × Metrado):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._localPartida.apuItems.where((a) => !a.isPercentageOfMO).map((apu) {
          final cantTotal = apu.cantidadConDesperdicio * m;
          final montoTotal = cantTotal * apu.precioUnitario;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(apu.resourceDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Requerido: ${_qtyFormat.format(cantTotal)} ${apu.unit}  •  P.U.: $currency ${_currencyFormat.format(apu.precioUnitario)}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Text(
                '$currency ${_currencyFormat.format(montoTotal)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConsolRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
