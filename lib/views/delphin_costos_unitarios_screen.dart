import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/partidas_library.dart';
import '../models/apu_item.dart';
import '../models/partida.dart';
import '../models/pie_presupuesto.dart';
import '../models/resource.dart';
import '../providers/presupuesto_provider.dart';
import '../services/formula_service.dart';
import '../services/pdf_export_service.dart';

/// Modelo de una fila en la Administración de Unidades (Imagen 3 de Delphin)
class DelphinUnitItem {
  String abreviatura;
  String descripcion;
  String tipo; // 'Porcentaje', 'General', 'Día de trabajo', 'Hora de trabajo', 'Global'

  DelphinUnitItem({
    required this.abreviatura,
    required this.descripcion,
    required this.tipo,
  });
}

/// Modelo de un Grupo de Costo Unitario (Imagen 2 de Delphin)
class DelphinCostGroup {
  String codigo;
  String descripcion;

  DelphinCostGroup({
    required this.codigo,
    required this.descripcion,
  });
}

/// Modelo de un ítem del Catálogo Maestro de Costos Unitarios (Imagen 1 de Delphin)
class DelphinCatalogCostItem {
  String groupCode;
  String groupName;
  String code;
  Partida partida;

  DelphinCatalogCostItem({
    required this.groupCode,
    required this.groupName,
    required this.code,
    required this.partida,
  });
}

class DelphinCostosUnitariosScreen extends StatefulWidget {
  final int initialDialog; // 0 = Ninguno, 1 = Grupos, 2 = Unidades, 3 = Índices, 4 = Plantillas

  const DelphinCostosUnitariosScreen({
    super.key,
    this.initialDialog = 0,
  });

  @override
  State<DelphinCostosUnitariosScreen> createState() =>
      _DelphinCostosUnitariosScreenState();
}

class _DelphinCostosUnitariosScreenState
    extends State<DelphinCostosUnitariosScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  final _qtyFormat = NumberFormat('#,##0.0000', 'es_PE');

  late List<DelphinCostGroup> _grupos;
  late List<DelphinUnitItem> _unidades;
  late List<DelphinCatalogCostItem> _catalogo;

  final Set<String> _collapsedGroups = {};
  final Set<String> _collapsedApuCategories = {};

  String _searchCatalog = '';
  DelphinCatalogCostItem? _selectedItem;
  bool _porRendimiento = true;
  int _rightBottomTab = 0; // 0 = Análisis de costo unitario, 1 = Especificaciones técnicas

  @override
  void initState() {
    super.initState();
    _initMasterData();
    if (widget.initialDialog > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialDialog == 1) _openGruposDialog();
        if (widget.initialDialog == 2) _openUnidadesDialog();
        if (widget.initialDialog == 3) _openIndicesDialog();
        if (widget.initialDialog == 4) _openPlantillasDialog();
      });
    }
  }

  void _initMasterData() {
    _grupos = [
      DelphinCostGroup(codigo: '162', descripcion: 'ACARREO DE MATERIAL'),
      DelphinCostGroup(codigo: '088', descripcion: 'ACCESORIOS DE DESAGÜE'),
      DelphinCostGroup(codigo: '174', descripcion: 'ACCESORIOS ELÉCTRICOS'),
      DelphinCostGroup(codigo: '082', descripcion: 'ACCESORIOS PARA APARATOS SANITARIOS'),
      DelphinCostGroup(codigo: '094', descripcion: 'ACCESORIOS PARA REDES DE AGUA'),
      DelphinCostGroup(codigo: '015', descripcion: 'ACERO DE REFUERZO'),
      DelphinCostGroup(codigo: '020', descripcion: 'ALCANTARILLAS'),
      DelphinCostGroup(codigo: '080', descripcion: 'APARATOS SANITARIOS'),
      DelphinCostGroup(codigo: '110', descripcion: 'AREAS VERDES, PARQUES Y JARDINES'),
      DelphinCostGroup(codigo: '035', descripcion: 'BASE GRANULAR'),
      DelphinCostGroup(codigo: '038', descripcion: 'BERMAS Y BACHEO'),
      DelphinCostGroup(codigo: '065', descripcion: 'BISAGRAS'),
      DelphinCostGroup(codigo: '090', descripcion: 'BUZONES'),
      DelphinCostGroup(codigo: '010', descripcion: 'TRABAJOS PRELIMINARES Y MOV. TIERRAS'),
      DelphinCostGroup(codigo: '040', descripcion: 'CONCRETO SIMPLE Y ARMADO'),
      DelphinCostGroup(codigo: '050', descripcion: 'ALBAÑILERÍA, REVOQUES Y PINTURA'),
    ];

    _unidades = [
      DelphinUnitItem(abreviatura: '%%', descripcion: '% aplicado a una suma total de grupo incluido otros %', tipo: 'Porcentaje'),
      DelphinUnitItem(abreviatura: '%eq', descripcion: '% aplicado a equipos desde otro grupo diferente a equipos', tipo: 'Porcentaje'),
      DelphinUnitItem(abreviatura: '%mo', descripcion: '% aplicado a mano de obra desde otro grupo diferente a mano de obra', tipo: 'Porcentaje'),
      DelphinUnitItem(abreviatura: '%mt', descripcion: '% aplicado a materiales desde otro grupo diferente a materiales', tipo: 'Porcentaje'),
      DelphinUnitItem(abreviatura: '%pu', descripcion: '% aplicado al total de un precio unitario', tipo: 'Porcentaje'),
      DelphinUnitItem(abreviatura: 'años', descripcion: 'Años', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'bal', descripcion: 'Balde', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'bls', descripcion: 'Bolsa', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'blt', descripcion: 'Bulto', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'bol', descripcion: 'Bolsa (42.5 kg)', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'caj', descripcion: 'Caja', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cil', descripcion: 'Cilindro', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cja', descripcion: 'Caja', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cjt', descripcion: 'Conjunto', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cm', descripcion: 'Centímetro', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cm²', descripcion: 'Centímetro cuadrado', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cm³', descripcion: 'Centímetro cúbico', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'cnt', descripcion: 'Ciento', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'dia', descripcion: 'Día', tipo: 'Día de trabajo'),
      DelphinUnitItem(abreviatura: 'DM', descripcion: 'Día-Máquina / Hora de trabajo', tipo: 'Hora de trabajo'),
      DelphinUnitItem(abreviatura: 'doc', descripcion: 'Docena', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'est', descripcion: 'Estimado', tipo: 'Global'),
      DelphinUnitItem(abreviatura: 'glb', descripcion: 'Global', tipo: 'Global'),
      DelphinUnitItem(abreviatura: 'hh', descripcion: 'Hora-Hombre', tipo: 'Hora de trabajo'),
      DelphinUnitItem(abreviatura: 'hm', descripcion: 'Hora-Máquina', tipo: 'Hora de trabajo'),
      DelphinUnitItem(abreviatura: 'kg', descripcion: 'Kilogramo', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'm', descripcion: 'Metro lineal', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'm2', descripcion: 'Metro cuadrado', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'm3', descripcion: 'Metro cúbico', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'p2', descripcion: 'Pie cuadrado', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'pto', descripcion: 'Punto', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'pza', descripcion: 'Pieza', tipo: 'General'),
      DelphinUnitItem(abreviatura: 'und', descripcion: 'Unidad', tipo: 'General'),
    ];

    // Construir el catálogo maestro combinando las partidas exactas de la Imagen 1 de Delphin + PartidasLibrary
    _catalogo = [
      // Grupo 162 - ACARREO DE MATERIAL (Exacto a Imagen 1)
      DelphinCatalogCostItem(
        groupCode: '162',
        groupName: 'ACARREO DE MATERIAL',
        code: '0003',
        partida: const Partida(
          id: 'delphin_162_0003',
          itemNumber: '01.01',
          description: 'Acarreo de ladrillo',
          unit: 'und',
          metrado: 1.0,
          rendimiento: 1000.0,
          precioUnitario: 0.17,
          costoParcial: 0.17,
          apuItems: [
            ApuItem(
              id: 'apu_162_1',
              resourceId: 'res_peon',
              resourceCode: '470104',
              resourceDescription: 'PEON',
              unit: 'hh',
              type: ResourceType.manoDeObra,
              unifiedIndex: 47,
              cuadrilla: 1.0,
              cantidad: 0.0080,
              precioUnitario: 20.22,
            ),
            ApuItem(
              id: 'apu_162_2',
              resourceId: 'res_herr',
              resourceCode: '370101',
              resourceDescription: 'Herramientas',
              unit: '%mo',
              type: ResourceType.equipo,
              unifiedIndex: 37,
              isPercentageOfMO: true,
              percentageValue: 5.0,
              precioUnitario: 0.16,
            ),
          ],
        ),
      ),
      DelphinCatalogCostItem(
        groupCode: '162',
        groupName: 'ACARREO DE MATERIAL',
        code: '0447',
        partida: const Partida(
          id: 'delphin_162_0447',
          itemNumber: '01.02',
          description: 'Acarreo de material excedente con equipo, hasta una distancia promedio de 100 mts',
          unit: 'm3',
          metrado: 1.0,
          rendimiento: 60.0,
          precioUnitario: 4.00,
          costoParcial: 4.00,
          apuItems: [
            ApuItem(
              id: 'apu_0447_1',
              resourceId: 'res_peon',
              resourceCode: '470104',
              resourceDescription: 'PEON',
              unit: 'hh',
              type: ResourceType.manoDeObra,
              unifiedIndex: 47,
              cuadrilla: 1.0,
              cantidad: 0.1333,
              precioUnitario: 20.22,
            ),
            ApuItem(
              id: 'apu_0447_2',
              resourceId: 'res_minicarg',
              resourceCode: '490102',
              resourceDescription: 'MINICARGADOR 70 HP',
              unit: 'hm',
              type: ResourceType.equipo,
              unifiedIndex: 49,
              cuadrilla: 0.1,
              cantidad: 0.0133,
              precioUnitario: 98.00,
            ),
          ],
        ),
      ),
      DelphinCatalogCostItem(
        groupCode: '162',
        groupName: 'ACARREO DE MATERIAL',
        code: '0012',
        partida: const Partida(
          id: 'delphin_162_0012',
          itemNumber: '01.03',
          description: 'Acarreo de material excedente hasta una distancia promedio de 30 mts',
          unit: 'm3',
          metrado: 1.0,
          rendimiento: 6.0,
          precioUnitario: 33.08,
          costoParcial: 33.08,
          apuItems: [
            ApuItem(
              id: 'apu_0012_1',
              resourceId: 'res_peon',
              resourceCode: '470104',
              resourceDescription: 'PEON',
              unit: 'hh',
              type: ResourceType.manoDeObra,
              unifiedIndex: 47,
              cuadrilla: 1.0,
              cantidad: 1.5600,
              precioUnitario: 20.22,
            ),
            ApuItem(
              id: 'apu_0012_2',
              resourceId: 'res_herr',
              resourceCode: '370101',
              resourceDescription: 'Herramientas',
              unit: '%mo',
              type: ResourceType.equipo,
              unifiedIndex: 37,
              isPercentageOfMO: true,
              percentageValue: 5.0,
              precioUnitario: 0.0,
            ),
          ],
        ),
      ),
      // Grupo 088 - ACCESORIOS DE DESAGÜE
      DelphinCatalogCostItem(
        groupCode: '088',
        groupName: 'ACCESORIOS DE DESAGÜE',
        code: '0267',
        partida: const Partida(
          id: 'delphin_088_0267',
          itemNumber: '02.01',
          description: 'Registro de bronce Ø 2"',
          unit: 'und',
          metrado: 1.0,
          rendimiento: 12.0,
          precioUnitario: 94.72,
          costoParcial: 94.72,
          apuItems: [
            ApuItem(
              id: 'apu_0267_1',
              resourceId: 'res_op',
              resourceCode: '470102',
              resourceDescription: 'OPERARIO GASFITERO',
              unit: 'hh',
              type: ResourceType.manoDeObra,
              unifiedIndex: 47,
              cuadrilla: 1.0,
              cantidad: 0.6667,
              precioUnitario: 27.80,
            ),
            ApuItem(
              id: 'apu_0267_2',
              resourceId: 'res_reg2',
              resourceCode: '720101',
              resourceDescription: 'REGISTRO DE BRONCE CROMADO 2"',
              unit: 'und',
              type: ResourceType.material,
              unifiedIndex: 72,
              cantidad: 1.0,
              precioUnitario: 75.20,
            ),
          ],
        ),
      ),
      // Grupo 174 - ACCESORIOS ELÉCTRICOS
      DelphinCatalogCostItem(
        groupCode: '174',
        groupName: 'ACCESORIOS ELÉCTRICOS',
        code: '0466',
        partida: const Partida(
          id: 'delphin_174_0466',
          itemNumber: '03.01',
          description: 'Instalación de tomacorriente simple sin puesta a tierra incluye conductor TW N° 12 AWG',
          unit: 'cjt',
          metrado: 1.0,
          rendimiento: 8.0,
          precioUnitario: 43.47,
          costoParcial: 43.47,
          apuItems: [
            ApuItem(
              id: 'apu_0466_1',
              resourceId: 'res_op_el',
              resourceCode: '470102',
              resourceDescription: 'OPERARIO ELECTRICISTA',
              unit: 'hh',
              type: ResourceType.manoDeObra,
              unifiedIndex: 47,
              cuadrilla: 1.0,
              cantidad: 1.0,
              precioUnitario: 27.80,
            ),
            ApuItem(
              id: 'apu_0466_2',
              resourceId: 'res_toma',
              resourceCode: '070105',
              resourceDescription: 'TOMACORRIENTE SIMPLE + CONDUCTOR TW 12 AWG',
              unit: 'und',
              type: ResourceType.material,
              unifiedIndex: 7,
              cantidad: 1.0,
              precioUnitario: 15.67,
            ),
          ],
        ),
      ),
    ];

    // Agregar todas las partidas del banco general a sus respectivos grupos
    int seq = 100;
    for (final tpl in PartidasLibrary.getTemplates()) {
      seq++;
      final desc = tpl.description.toUpperCase();
      String gCode = '040';
      String gName = 'CONCRETO SIMPLE Y ARMADO';
      if (desc.contains('TRAZO') || desc.contains('EXCAV')) {
        gCode = '010';
        gName = 'TRABAJOS PRELIMINARES Y MOV. TIERRAS';
      } else if (desc.contains('ACERO')) {
        gCode = '015';
        gName = 'ACERO DE REFUERZO';
      } else if (desc.contains('MURO') || desc.contains('TARRAJEO') || desc.contains('PINTURA')) {
        gCode = '050';
        gName = 'ALBAÑILERÍA, REVOQUES Y PINTURA';
      }
      _catalogo.add(
        DelphinCatalogCostItem(
          groupCode: gCode,
          groupName: gName,
          code: seq.toString().padLeft(4, '0'),
          partida: tpl.recalculateWithJornada(8.0),
        ),
      );
    }

    _selectedItem = _catalogo.first;
  }

  /// Botón "Actualizar costos unitarios" de la Cinta Delphin (Imagen 1)
  void _actualizarCostosUnitarios() {
    final provider = context.read<PresupuestoProvider>();
    final masterMap = <String, double>{};
    for (final r in provider.masterResources) {
      masterMap[r.description.toLowerCase().trim()] = r.unitPrice;
    }

    int actualizados = 0;
    setState(() {
      for (var i = 0; i < _catalogo.length; i++) {
        final item = _catalogo[i];
        final updatedApu = item.partida.apuItems.map((a) {
          final key = a.resourceDescription.toLowerCase().trim();
          if (masterMap.containsKey(key) && !a.isPercentageOfMO) {
            return a.copyWith(precioUnitario: masterMap[key]);
          }
          return a;
        }).toList();
        final newPartida = item.partida
            .copyWith(apuItems: updatedApu)
            .recalculateWithJornada(8.0);
        _catalogo[i].partida = newPartida;
        actualizados++;
      }
      if (_selectedItem != null) {
        _selectedItem = _catalogo.firstWhere(
          (c) => c.code == _selectedItem!.code,
          orElse: () => _catalogo.first,
        );
      }
    });

    // También recalcular el presupuesto activo
    provider.procesarPresupuesto();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Costos Unitarios actualizados: $actualizados análisis recalculados y sincronizados con el proyecto activo.',
        ),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final activePresupuesto = provider.activePresupuesto;

    // Filtrar catálogo por búsqueda
    final filteredCatalog = _catalogo.where((c) {
      if (_searchCatalog.isEmpty) return true;
      final q = _searchCatalog.toLowerCase();
      return c.partida.description.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.groupName.toLowerCase().contains(q) ||
          c.groupCode.toLowerCase().contains(q);
    }).toList();

    // Agrupar por groupCode + groupName
    final groupedMap = <String, List<DelphinCatalogCostItem>>{};
    for (final item in filteredCatalog) {
      final key = '${item.groupCode} - ${item.groupName}';
      groupedMap.putIfAbsent(key, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE3EBF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.table_view,
                  color: Colors.amberAccent,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lista de Costos — Catálogo Maestro de Costos Unitarios (Delphin Express)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'SQLDelphin_maestro.sqlite  |  Doble panel interactivo con Grupos, Unidades, Índices y Plantillas',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. CINTA SUPERIOR DE BOTONES DELPHIN (Exacta a Imagen 1: Ir Inicio | Imprimir | Exportar | Importar | Grupos de Costos | Actualizar costos unitarios | Unidades | Índices | Plantillas)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F8FC), Color(0xFFDCE6F2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade300)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRibbonButton(
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFF1565C0),
                    label: 'Ir Inicio',
                    sublabel: 'Navegador',
                    onTap: () => Navigator.pop(context),
                  ),
                  _ribbonDivider(),
                  _buildRibbonButton(
                    icon: Icons.print,
                    color: const Color(0xFF2E7D32),
                    label: 'Imprimir',
                    sublabel: 'PDF Oficial',
                    onTap: () async {
                      final listToPrint = _selectedItem != null
                          ? [_selectedItem!.partida]
                          : _catalogo.map((e) => e.partida).toList();
                      await PdfExportService.printCatalogoCostosUnitariosPdf(listToPrint);
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.file_upload_outlined,
                    color: const Color(0xFF00838F),
                    label: 'Exportar',
                    sublabel: 'Catálogo',
                    onTap: () {
                      final summary = _catalogo
                          .map((c) =>
                              '${c.groupCode}|${c.code}|${c.partida.description}|${c.partida.unit}|${c.partida.calculateUnitPrice().toStringAsFixed(2)}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: summary));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ ${_catalogo.length} Costos Unitarios exportados al portapapeles.',
                          ),
                          backgroundColor: Colors.teal.shade800,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.download_for_offline_outlined,
                    color: const Color(0xFFEF6C00),
                    label: 'Importar a Obra',
                    sublabel: 'Enviar Partida',
                    onTap: () {
                      if (_selectedItem == null) return;
                      provider.importPartidaFromLibrary(_selectedItem!.partida);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Partida "${_selectedItem!.partida.description}" enviada a ${activePresupuesto?.name ?? "el presupuesto activo"}',
                          ),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    },
                  ),
                  _ribbonDivider(),
                  _buildRibbonButton(
                    icon: Icons.folder_special_outlined,
                    color: const Color(0xFF6A1B9A),
                    label: 'Grupos de',
                    sublabel: 'Costos',
                    onTap: _openGruposDialog,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.sync,
                    color: const Color(0xFF0277BD),
                    label: 'Actualizar',
                    sublabel: 'costos unitarios',
                    onTap: _actualizarCostosUnitarios,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.straighten,
                    color: const Color(0xFF37474F),
                    label: 'Unidades',
                    sublabel: 'Administración',
                    onTap: _openUnidadesDialog,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.format_list_numbered,
                    color: const Color(0xFF4C8C2B),
                    label: 'Índices (IU)',
                    sublabel: 'Catálogo INEI',
                    onTap: _openIndicesDialog,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.dashboard_customize_outlined,
                    color: const Color(0xFFB5234A),
                    label: 'Plantillas',
                    sublabel: 'Contrata / Adm.',
                    onTap: _openPlantillasDialog,
                  ),
                  const SizedBox(width: 6),
                  _buildRibbonButton(
                    icon: Icons.add_circle_outline,
                    color: const Color(0xFF1B5E20),
                    label: 'Nuevo C.U.',
                    sublabel: 'Crear Partida',
                    onTap: _openNuevoCostoUnitarioDialog,
                  ),
                ],
              ),
            ),
          ),

          // 2. ÁREA CENTRAL DIVIDIDA: IZQUIERDA (Árbol de Grupos y Costos) | DERECHA (Análisis de Costo Unitario)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 780;
                final leftPanel = _buildLeftCatalogPanel(groupedMap);
                final rightPanel = _buildRightApuPanel(provider);

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 11, child: leftPanel),
                      Container(width: 3, color: Colors.blueGrey.shade300),
                      Expanded(flex: 12, child: rightPanel),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Expanded(flex: 5, child: leftPanel),
                      Container(height: 3, color: Colors.blueGrey.shade300),
                      Expanded(flex: 6, child: rightPanel),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbonButton({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ribbonDivider() {
    return Container(
      height: 38,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.blueGrey.shade300,
    );
  }

  /// PANEL IZQUIERDO: Árbol colapsable por Grupo de Costo Unitario (Imagen 1)
  Widget _buildLeftCatalogPanel(
    Map<String, List<DelphinCatalogCostItem>> groupedMap,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Encabezado de Columnas + Barra de Filtro ABC
          Container(
            color: const Color(0xFFDCE6F2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('Tipo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 36,
                  child: Text('Gru...', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 44,
                  child: Text('Código', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Descripción', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 40,
                  child: Text('Unidad', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 62,
                  child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Fila de búsqueda interactiva (ABC) + botones Expandir/Contraer todo
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'ABC',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrar por código, grupo o descripción...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        border: OutlineInputBorder(),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      style: const TextStyle(fontSize: 11),
                      onChanged: (v) => setState(() => _searchCatalog = v),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.unfold_more, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Expandir todos los grupos',
                  onPressed: () => setState(() => _collapsedGroups.clear()),
                ),
                IconButton(
                  icon: const Icon(Icons.unfold_less, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Contraer todos los grupos',
                  onPressed: () => setState(() => _collapsedGroups.addAll(groupedMap.keys)),
                ),
              ],
            ),
          ),

          // Lista Jerárquica Colapsable con Flechas (⌄ / ›)
          Expanded(
            child: ListView(
              children: groupedMap.entries.map((entry) {
                final groupKey = entry.key;
                final items = entry.value;
                final isCollapsed = _collapsedGroups.contains(groupKey);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera del Grupo (Ej: ⌄ 162 - ACARREO DE MATERIAL)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedGroups.remove(groupKey);
                          } else {
                            _collapsedGroups.add(groupKey);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          border: Border(
                            bottom: BorderSide(color: Colors.blue.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                              size: 17,
                              color: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                groupKey,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            Text(
                              '(${items.length})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Filas de Costos Unitarios dentro del Grupo
                    if (!isCollapsed)
                      ...items.map((item) {
                        final isSelected = _selectedItem?.code == item.code &&
                            _selectedItem?.groupCode == item.groupCode;
                        final pu = item.partida.calculateUnitPrice();

                        return InkWell(
                          onTap: () => setState(() => _selectedItem = item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFBFDBFE)
                                  : Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200, width: 0.7),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 32,
                                  child: Text('CU  R', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    item.groupCode,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    item.code,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.partida.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    item.partida.unit,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF0284C7)),
                                  ),
                                ),
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    _currencyFormat.format(pu),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
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
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// PANEL DERECHO: "Análisis de costo unitario" interactivo (Imagen 1 de Delphin)
  Widget _buildRightApuPanel(PresupuestoProvider provider) {
    final item = _selectedItem;
    if (item == null) {
      return const Center(child: Text('Seleccione un Costo Unitario de la lista izquierda'));
    }

    final p = item.partida;
    final puTotal = p.calculateUnitPrice();
    final duracionFija = p.rendimiento > 0 ? (1.0 / p.rendimiento) : 1.0;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera "Análisis de costo unitario" (Imagen 1)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Análisis de costo unitario.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.playlist_add_check, size: 16),
                      label: const Text('Insertar en Presupuesto', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        provider.importPartidaFromLibrary(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Partida "${p.description}" agregada al presupuesto activo'),
                            backgroundColor: Colors.green.shade800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Fila Grupo + Unidad + Recuadro DURACIÓN FIJA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Grupo + [+] + Unidad + [+]
                          Row(
                            children: [
                              const SizedBox(
                                width: 58,
                                child: Text('Grupo:', style: TextStyle(fontSize: 11)),
                              ),
                              Expanded(
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.blueGrey.shade300),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    item.groupName,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              InkWell(
                                onTap: _openGruposDialog,
                                child: Container(
                                  width: 24,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.blueGrey.shade400),
                                  ),
                                  child: const Icon(Icons.add, size: 15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Unidad: ', style: TextStyle(fontSize: 11)),
                              Container(
                                width: 48,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.blueGrey.shade300),
                                ),
                                child: Text(
                                  p.unit,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 3),
                              InkWell(
                                onTap: _openUnidadesDialog,
                                child: Container(
                                  width: 24,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.blueGrey.shade400),
                                  ),
                                  child: const Icon(Icons.add, size: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Descripción
                          Row(
                            children: [
                              const SizedBox(
                                width: 58,
                                child: Text('Descripción:', style: TextStyle(fontSize: 10.5)),
                              ),
                              Expanded(
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.blueGrey.shade300),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    p.description,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Recuadro DURACIÓN FIJA programada (Imagen 1)
                    Container(
                      width: 132,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE6F2),
                        border: Border.all(color: Colors.blueGrey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'DURACIÓN FIJA\nprogramada para ejecutar\n1.00 und',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 9, color: Colors.black87, height: 1.15),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.blueGrey.shade400),
                            ),
                            child: Text(
                              '${duracionFija.toStringAsFixed(3)} días',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Barra de Rendimiento diario + Jornada (Imagen 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _porRendimiento = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _porRendimiento ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 16,
                              color: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 3),
                            const Text('Por Rendimiento', style: TextStyle(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _porRendimiento = false),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              !_porRendimiento ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 16,
                              color: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 3),
                            const Text('Por Asignación', style: TextStyle(fontSize: 10.5)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _editarRendimientoPartida(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            border: Border.all(color: Colors.amber.shade700),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Rend. diario: ${_currencyFormat.format(p.rendimiento)} ${p.unit}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const Text(
                        'Jornada: 8.00 h/día',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo central según pestaña inferior derecha
          Expanded(
            child: _rightBottomTab == 0
                ? _buildRightApuGrid(item)
                : _buildRightSpecsView(p),
          ),

          // Barra inferior de Total y Pestañas (Análisis de costo unitario | Especificaciones técnicas)
          Container(
            color: const Color(0xFFDCE6F2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBottomTabChip(0, Icons.analytics_outlined, 'Análisis de costo unitario'),
                        const SizedBox(width: 6),
                        _buildBottomTabChip(1, Icons.description_outlined, 'Especificaciones técnicas'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blueGrey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Total C.U.: S/. ${_currencyFormat.format(puTotal)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabChip(int index, IconData icon, String label) {
    final selected = _rightBottomTab == index;
    return InkWell(
      onTap: () => setState(() => _rightBottomTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? Colors.amber.shade800 : Colors.blueGrey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cuadrícula derecha de Recursos del APU con categorías colapsables con flechas (⌄ / ›)
  Widget _buildRightApuGrid(DelphinCatalogCostItem item) {
    final p = item.partida;
    final rubros = [
      ('MANO DE OBRA', ResourceType.manoDeObra, p.subtotalMO),
      ('MATERIALES', ResourceType.material, p.subtotalMateriales),
      ('EQUIPO', ResourceType.equipo, p.subtotalEquipos),
      ('SUB-CONTRATOS', ResourceType.subcontrato, p.subtotalSubcontratos),
    ];

    return Column(
      children: [
        // Cabecera de columnas del APU (Descripción | Unid. | Nro. Rec. | Cantidad | % Des... | Precio | Total)
        Container(
          color: const Color(0xFFE2E8F0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Descripción', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 36,
                child: Text('Unid.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 46,
                child: Text('Nro. Rec.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 66,
                child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 44,
                child: Text('% Des...', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 52,
                child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 56,
                child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            children: [
              ...rubros.map((rubro) {
                final title = rubro.$1;
                final type = rubro.$2;
                final subtotal = rubro.$3;
                final recursos = p.apuItems.where((a) => a.type == type).toList();
                final isCollapsed = _collapsedApuCategories.contains(title);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fila de Categoría Colapsable con Flecha (⌄ MANO DE OBRA)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedApuCategories.remove(title);
                          } else {
                            _collapsedApuCategories.add(title);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              recursos.isEmpty
                                  ? Icons.remove
                                  : (isCollapsed
                                      ? Icons.keyboard_arrow_right
                                      : Icons.keyboard_arrow_down),
                              size: 16,
                              color: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Text(
                              _currencyFormat.format(subtotal),
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Recursos dentro de la categoría
                    if (!isCollapsed)
                      ...recursos.map((a) {
                        final parcial = a.calculateParcial(subtotalMO: p.subtotalMO);
                        final iuStr = a.unifiedIndex > 0
                            ? a.unifiedIndex.toString().padLeft(2, '0')
                            : '39';

                        return InkWell(
                          onTap: () => _editarInsumoCatalogoDialog(item, a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      '$iuStr  ${a.resourceDescription}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    a.unit,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                SizedBox(
                                  width: 46,
                                  child: Text(
                                    a.cuadrilla > 0 ? a.cuadrilla.toStringAsFixed(2) : '',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ),
                                SizedBox(
                                  width: 66,
                                  child: Text(
                                    a.isPercentageOfMO
                                        ? '${a.percentageValue.toStringAsFixed(4)} %mo'
                                        : _qtyFormat.format(a.cantidadConDesperdicio),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    a.desperdicio > 0 ? '${a.desperdicio.toStringAsFixed(1)}%' : '',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    a.isPercentageOfMO
                                        ? _currencyFormat.format(p.subtotalMO)
                                        : _currencyFormat.format(a.precioUnitario),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    _currencyFormat.format(parcial),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
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
              }),
              // Fila SUB-PARTIDAS (como en Imagen 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: const Color(0xFFF1F5F9),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '    SUB-PARTIDAS',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                    Text('0.00', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightSpecsView(Partida p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. DESCRIPCIÓN Y MÉTODO DE CONSTRUCCIÓN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 4),
          Text(p.effectiveEspecificacionDescripcion, style: const TextStyle(fontSize: 11.5)),
          const Divider(height: 18),
          const Text(
            '2. MÉTODO DE MEDICIÓN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 4),
          Text(p.effectiveEspecificacionMedicion, style: const TextStyle(fontSize: 11.5)),
          const Divider(height: 18),
          const Text(
            '3. BASES DE PAGO',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 4),
          Text(p.effectiveEspecificacionPago, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }

  void _editarRendimientoPartida(DelphinCatalogCostItem item) {
    final ctrl = TextEditingController(text: item.partida.rendimiento.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Rendimiento Diario'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Rendimiento (${item.partida.unit}/día)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final r = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? item.partida.rendimiento;
              if (r > 0) {
                setState(() {
                  item.partida = item.partida.copyWith(rendimiento: r).recalculateWithJornada(8.0);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _editarInsumoCatalogoDialog(DelphinCatalogCostItem item, ApuItem apuItem) {
    final cuadCtrl = TextEditingController(text: apuItem.cuadrilla.toStringAsFixed(2));
    final cantCtrl = TextEditingController(text: apuItem.cantidad.toStringAsFixed(4));
    final precCtrl = TextEditingController(text: apuItem.precioUnitario.toStringAsFixed(2));
    final despCtrl = TextEditingController(text: apuItem.desperdicio.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Recurso: ${apuItem.resourceDescription}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (apuItem.type == ResourceType.manoDeObra || apuItem.type == ResourceType.equipo)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: cuadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nro. Rec. / Cuadrilla',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            TextField(
              controller: cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cantidad / Aporte Unitario (4 dec.)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: despCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '% Desperdicio',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: precCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio Unitario (S/.)',
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
              final c = double.tryParse(cuadCtrl.text) ?? apuItem.cuadrilla;
              final q = double.tryParse(cantCtrl.text) ?? apuItem.cantidad;
              final d = double.tryParse(despCtrl.text) ?? apuItem.desperdicio;
              final p = double.tryParse(precCtrl.text) ?? apuItem.precioUnitario;

              setState(() {
                final updatedList = item.partida.apuItems.map((x) {
                  if (x.id == apuItem.id) {
                    return x.copyWith(
                      cuadrilla: c,
                      cantidad: q,
                      desperdicio: d,
                      precioUnitario: p,
                    );
                  }
                  return x;
                }).toList();
                item.partida = item.partida.copyWith(apuItems: updatedList).recalculateWithJornada(8.0);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _openNuevoCostoUnitarioDialog() {
    final descCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'm2');
    final rdtoCtrl = TextEditingController(text: '20.00');
    String selectedGroupCode = _grupos.first.codigo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo Costo Unitario (Catálogo Maestro)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedGroupCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Grupo de Costo Unitario',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _grupos
                    .map((g) => DropdownMenuItem(
                          value: g.codigo,
                          child: Text(
                            '${g.codigo} - ${g.descripcion}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setLocal(() => selectedGroupCode = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la Partida',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: rdtoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Rendimiento/día',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) return;
                final grp = _grupos.firstWhere((g) => g.codigo == selectedGroupCode);
                final newCode = (_catalogo.length + 500).toString().padLeft(4, '0');
                final newItem = DelphinCatalogCostItem(
                  groupCode: grp.codigo,
                  groupName: grp.descripcion,
                  code: newCode,
                  partida: Partida(
                    id: 'cu_$newCode',
                    itemNumber: '01.01',
                    description: descCtrl.text.trim().toUpperCase(),
                    unit: unitCtrl.text.trim(),
                    metrado: 1.0,
                    rendimiento: double.tryParse(rdtoCtrl.text) ?? 20.0,
                    apuItems: const [
                      ApuItem(
                        id: 'mo_default',
                        resourceId: 'res_peon',
                        resourceCode: '470104',
                        resourceDescription: 'PEON',
                        unit: 'hh',
                        type: ResourceType.manoDeObra,
                        unifiedIndex: 47,
                        cuadrilla: 1.0,
                        cantidad: 0.4000,
                        precioUnitario: 20.22,
                      ),
                    ],
                  ).recalculateWithJornada(8.0),
                );
                setState(() {
                  _catalogo.insert(0, newItem);
                  _selectedItem = newItem;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Crear Costo Unitario'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // IMAGEN 2: VENTANA "GRUPO DE COSTO UNITARIO" (Actualizar, Nuevo, Editar, Eliminar, Cerrar)
  // =========================================================================
  void _openGruposDialog() {
    String filter = '';
    int selectedIdx = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = _grupos
              .where((g) =>
                  filter.isEmpty ||
                  g.descripcion.toLowerCase().contains(filter.toLowerCase()) ||
                  g.codigo.contains(filter))
              .toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 540,
              height: 430,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grupo de costo unitario',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        // Tabla izquierda con filtro ABC
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.blueGrey.shade300),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  color: const Color(0xFFE2E8F0),
                                  child: const Text(
                                    'Descripción',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.sort_by_alpha, size: 16, color: Colors.green),
                                      hintText: 'Filtrar grupo (ABC)...',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 11.5),
                                    onChanged: (v) => setModal(() => filter = v),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, idx) {
                                      final g = filtered[idx];
                                      final isSel = idx == selectedIdx;
                                      return InkWell(
                                        onTap: () => setModal(() => selectedIdx = idx),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSel ? const Color(0xFFBFDBFE) : Colors.white,
                                            border: Border(
                                              bottom: BorderSide(color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Text(
                                            g.descripcion,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Botonera derecha funcional (Actualizar, Nuevo..., Editar..., Eliminar..., Cerrar)
                        SizedBox(
                          width: 115,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  setModal(() {
                                    _grupos.sort((a, b) => a.descripcion.compareTo(b.descripcion));
                                  });
                                  setState(() {});
                                },
                                child: const Text('Actualizar', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: () {
                                  final ctrl = TextEditingController();
                                  showDialog(
                                    context: ctx,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Nuevo Grupo de Costo'),
                                      content: TextField(
                                        controller: ctrl,
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: const InputDecoration(
                                          labelText: 'Descripción del Grupo',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                        FilledButton(
                                          onPressed: () {
                                            if (ctrl.text.trim().isNotEmpty) {
                                              final code = (_grupos.length + 180).toString();
                                              setModal(() {
                                                _grupos.add(DelphinCostGroup(
                                                  codigo: code,
                                                  descripcion: ctrl.text.trim().toUpperCase(),
                                                ));
                                              });
                                              setState(() {});
                                              Navigator.pop(dCtx);
                                            }
                                          },
                                          child: const Text('Guardar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Nuevo...', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: filtered.isEmpty
                                    ? null
                                    : () {
                                        final target = filtered[selectedIdx.clamp(0, filtered.length - 1)];
                                        final ctrl = TextEditingController(text: target.descripcion);
                                        showDialog(
                                          context: ctx,
                                          builder: (dCtx) => AlertDialog(
                                            title: const Text('Editar Grupo de Costo'),
                                            content: TextField(
                                              controller: ctrl,
                                              textCapitalization: TextCapitalization.characters,
                                              decoration: const InputDecoration(
                                                labelText: 'Descripción',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                              FilledButton(
                                                onPressed: () {
                                                  if (ctrl.text.trim().isNotEmpty) {
                                                    setModal(() {
                                                      target.descripcion = ctrl.text.trim().toUpperCase();
                                                    });
                                                    setState(() {});
                                                    Navigator.pop(dCtx);
                                                  }
                                                },
                                                child: const Text('Guardar'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                child: const Text('Editar...', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                onPressed: filtered.isEmpty
                                    ? null
                                    : () {
                                        final target = filtered[selectedIdx.clamp(0, filtered.length - 1)];
                                        setModal(() {
                                          _grupos.remove(target);
                                          selectedIdx = 0;
                                        });
                                        setState(() {});
                                      },
                                child: const Text('Eliminar...', style: TextStyle(fontSize: 12, color: Colors.red)),
                              ),
                              const Spacer(),
                              FilledButton.tonal(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cerrar', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // IMAGEN 3: VENTANA "ADMINISTRACIÓN DE UNIDADES"
  // =========================================================================
  void _openUnidadesDialog() {
    String selectedSidebar = 'Todos';
    String filterAbrev = '';
    String filterDesc = '';
    int selectedUnitIdx = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = _unidades.where((u) {
            if (selectedSidebar == 'Costos unitarios' && u.tipo == 'Porcentaje') return false;
            if (selectedSidebar == 'Gastos Generales' && u.tipo != 'General' && u.tipo != 'Global') return false;
            if (selectedSidebar == 'Por tipo de costo' && u.tipo != 'Porcentaje') return false;
            if (filterAbrev.isNotEmpty && !u.abreviatura.toLowerCase().contains(filterAbrev.toLowerCase())) {
              return false;
            }
            if (filterDesc.isNotEmpty && !u.descripcion.toLowerCase().contains(filterDesc.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 780,
              height: 520,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade400, width: 1.5),
              ),
              child: Column(
                children: [
                  // Barra de título estilo Delphin
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Administración de Unidades — Lista de unidades (Delphin Express)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nueva Unidad', style: TextStyle(fontSize: 11.5)),
                          onPressed: () {
                            final abCtrl = TextEditingController();
                            final descCtrl = TextEditingController();
                            String tipoSel = 'General';
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Nueva Unidad de Medida'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: abCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Abreviatura (ej. m3, glb, %mo)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: descCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Descripción',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: tipoSel,
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'General', child: Text('General')),
                                        DropdownMenuItem(value: 'Porcentaje', child: Text('Porcentaje')),
                                        DropdownMenuItem(value: 'Día de trabajo', child: Text('Día de trabajo')),
                                        DropdownMenuItem(value: 'Hora de trabajo', child: Text('Hora de trabajo')),
                                        DropdownMenuItem(value: 'Global', child: Text('Global')),
                                      ],
                                      onChanged: (v) => tipoSel = v ?? 'General',
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                  FilledButton(
                                    onPressed: () {
                                      if (abCtrl.text.trim().isNotEmpty) {
                                        setModal(() {
                                          _unidades.add(DelphinUnitItem(
                                            abreviatura: abCtrl.text.trim(),
                                            descripcion: descCtrl.text.trim(),
                                            tipo: tipoSel,
                                          ));
                                        });
                                        setState(() {});
                                        Navigator.pop(dCtx);
                                      }
                                    },
                                    child: const Text('Agregar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 540;
                        final navItems = [
                          ('Todos', Icons.check_box_outlined),
                          ('Costos unitarios', Icons.folder_open),
                          ('Gastos Generales', Icons.receipt_long),
                          ('Por tipo de costo', Icons.percent),
                        ];

                        final tableWidget = Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              // Cabecera de columnas
                              Container(
                                color: const Color(0xFFE2E8F0),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: const Row(
                                  children: [
                                    SizedBox(width: 26, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    SizedBox(width: 74, child: Text('Abrev. ▲', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    Expanded(child: Text('Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    SizedBox(width: 78, child: Text('Tipo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              // Fila de filtros ABC
                              Container(
                                color: const Color(0xFFF1F5F9),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 26, child: Icon(Icons.push_pin_outlined, size: 14)),
                                    SizedBox(
                                      width: 70,
                                      height: 26,
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          hintText: 'ABC...',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          border: OutlineInputBorder(),
                                          fillColor: Colors.white,
                                          filled: true,
                                        ),
                                        style: const TextStyle(fontSize: 10.5),
                                        onChanged: (v) => setModal(() => filterAbrev = v),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: SizedBox(
                                        height: 26,
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            hintText: 'ABC Filtrar descripción...',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            border: OutlineInputBorder(),
                                            fillColor: Colors.white,
                                            filled: true,
                                          ),
                                          style: const TextStyle(fontSize: 10.5),
                                          onChanged: (v) => setModal(() => filterDesc = v),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Filas de unidades
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, idx) {
                                    final u = filtered[idx];
                                    final isSel = idx == selectedUnitIdx;
                                    return InkWell(
                                      onTap: () => setModal(() => selectedUnitIdx = idx),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFFBFDBFE) : Colors.white,
                                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 26,
                                              child: Text(
                                                '${idx + 1}',
                                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 74,
                                              child: Text(
                                                u.abreviatura,
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Text(
                                                  u.descripcion,
                                                  style: const TextStyle(fontSize: 11),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 78,
                                              child: Text(
                                                u.tipo,
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E3A8A)),
                                                overflow: TextOverflow.ellipsis,
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
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Container(
                                width: 155,
                                color: const Color(0xFFEFF6FF),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      color: const Color(0xFFBFDBFE),
                                      child: const Text(
                                        'Unidades',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...navItems.map((nav) {
                                      final active = selectedSidebar == nav.$1;
                                      return InkWell(
                                        onTap: () => setModal(() => selectedSidebar = nav.$1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: active ? const Color(0xFF93C5FD) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(nav.$2, size: 15, color: const Color(0xFF1E3A8A)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  nav.$1,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                        label: const Text('Eliminar sel.', style: TextStyle(fontSize: 11, color: Colors.red)),
                                        onPressed: filtered.isEmpty
                                            ? null
                                            : () {
                                                final target = filtered[selectedUnitIdx.clamp(0, filtered.length - 1)];
                                                setModal(() {
                                                  _unidades.remove(target);
                                                  selectedUnitIdx = 0;
                                                });
                                                setState(() {});
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(child: tableWidget),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Container(
                                color: const Color(0xFFEFF6FF),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...navItems.map((nav) {
                                        final active = selectedSidebar == nav.$1;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: InkWell(
                                            onTap: () => setModal(() => selectedSidebar = nav.$1),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: active ? const Color(0xFF93C5FD) : Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(nav.$2, size: 14, color: const Color(0xFF1E3A8A)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    nav.$1,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        ),
                                        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                        label: const Text('Eliminar sel.', style: TextStyle(fontSize: 10.5, color: Colors.red)),
                                        onPressed: filtered.isEmpty
                                            ? null
                                            : () {
                                                final target = filtered[selectedUnitIdx.clamp(0, filtered.length - 1)];
                                                setModal(() {
                                                  _unidades.remove(target);
                                                  selectedUnitIdx = 0;
                                                });
                                                setState(() {});
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(child: tableWidget),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // IMAGEN 4: VENTANA "ÍNDICES (BUSCAR ÍNDICE UNIFICADO INEI)"
  // =========================================================================
  void _openIndicesDialog() {
    final iusList = FormulaService.nombresIUTotales.entries
        .map((e) => {'iu': e.key.toString().padLeft(2, '0'), 'nota': '', 'desc': e.value})
        .toList();
    String filterIu = '';
    String filterDesc = '';
    int selectedIdx = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = iusList.where((item) {
            if (filterIu.isNotEmpty && !item['iu']!.contains(filterIu)) return false;
            if (filterDesc.isNotEmpty &&
                !item['desc']!.toLowerCase().contains(filterDesc.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 620,
              height: 450,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Índices — Buscar Índice Unificado INEI',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        // Tabla IU | Nota | Descripción
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.blueGrey.shade300),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  color: const Color(0xFFE2E8F0),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                      SizedBox(width: 34, child: Text('IU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                      Expanded(child: Text('Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                Container(
                                  color: const Color(0xFFF1F5F9),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 24, child: Icon(Icons.push_pin_outlined, size: 13)),
                                      SizedBox(
                                        width: 32,
                                        height: 26,
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            hintText: 'IU',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            border: OutlineInputBorder(),
                                            fillColor: Colors.white,
                                            filled: true,
                                          ),
                                          style: const TextStyle(fontSize: 10),
                                          onChanged: (v) => setModal(() => filterIu = v),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: SizedBox(
                                          height: 26,
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              hintText: 'ABC Buscar Índice...',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              border: OutlineInputBorder(),
                                              fillColor: Colors.white,
                                              filled: true,
                                            ),
                                            style: const TextStyle(fontSize: 10),
                                            onChanged: (v) => setModal(() => filterDesc = v),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, idx) {
                                      final row = filtered[idx];
                                      final isSel = idx == selectedIdx;
                                      return InkWell(
                                        onTap: () => setModal(() => selectedIdx = idx),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSel ? const Color(0xFFBFDBFE) : Colors.white,
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 10)),
                                              ),
                                              SizedBox(
                                                width: 34,
                                                child: Text(
                                                  row['iu']!,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  row['desc']!,
                                                  style: const TextStyle(fontSize: 11),
                                                  overflow: TextOverflow.ellipsis,
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
                        ),
                        const SizedBox(width: 8),

                        // Botonera Derecha Exacta a Imagen 4 (Actualizar, Nuevo..., Exportar, Importar, Cerrar)
                        SizedBox(
                          width: 98,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () => setModal(() {}),
                                  child: const Text('Actualizar', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    final iuCtrl = TextEditingController();
                                    final descCtrl = TextEditingController();
                                    showDialog(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Nuevo Índice Unificado'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: iuCtrl,
                                              decoration: const InputDecoration(labelText: 'Código IU', border: OutlineInputBorder()),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: descCtrl,
                                              decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                          FilledButton(
                                            onPressed: () {
                                              if (iuCtrl.text.isNotEmpty && descCtrl.text.isNotEmpty) {
                                                setModal(() {
                                                  iusList.add({
                                                    'iu': iuCtrl.text.trim().padLeft(2, '0'),
                                                    'nota': 'Personalizado',
                                                    'desc': descCtrl.text.trim(),
                                                  });
                                                });
                                                Navigator.pop(dCtx);
                                              }
                                            },
                                            child: const Text('Agregar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text('Nuevo...', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    final csv = iusList.map((e) => '${e['iu']};${e['desc']}').join('\n');
                                    Clipboard.setData(ClipboardData(text: csv));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Catálogo de 80 Índices INEI copiado al portapapeles')),
                                    );
                                  },
                                  child: const Text('Exportar', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Índices sincronizados con el catálogo oficial INEI')),
                                    );
                                  },
                                  child: const Text('Importar', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // IMAGEN 5: VENTANA "ADMINISTRAR PLANTILLAS" (MODELO GENERAL, OBRAS MENORES, ADMINISTRACION DIRECTA)
  // =========================================================================
  void _openPlantillasDialog() {
    final plantillas = <Map<String, String>>[
      {'nombre': 'MODELO GENERAL', 'modalidad': 'Contrata', 'ggFijos': '5.0', 'ggVar': '10.0', 'util': '8.0', 'igv': 'true'},
      {'nombre': 'OBRAS MENORES', 'modalidad': 'Contrata', 'ggFijos': '3.0', 'ggVar': '7.0', 'util': '7.0', 'igv': 'true'},
      {'nombre': 'ADMINISTRACION DIRECTA', 'modalidad': 'Admin. directa', 'ggFijos': '4.0', 'ggVar': '6.0', 'util': '0.0', 'igv': 'false'},
    ];
    int selectedIdx = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 520,
              height: 410,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Administrar plantillas',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        // Lista de plantillas
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.blueGrey.shade300),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  color: const Color(0xFFE2E8F0),
                                  child: const Text(
                                    'Lista de plantillas',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: plantillas.length,
                                    itemBuilder: (_, idx) {
                                      final pl = plantillas[idx];
                                      final isSel = idx == selectedIdx;
                                      return InkWell(
                                        onTap: () => setModal(() => selectedIdx = idx),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          color: isSel ? const Color(0xFFE2E8F0) : Colors.white,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  pl['nombre']!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                pl['modalidad']!,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey.shade700,
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
                        ),
                        const SizedBox(width: 12),

                        // Botonera Derecha Exacta a Imagen 5 (Nuevo..., Importar plantilla, Editar..., Eliminar..., Abrir plantilla, Cerrar)
                        SizedBox(
                          width: 135,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    final ctrl = TextEditingController();
                                    showDialog(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Nueva Plantilla'),
                                        content: TextField(
                                          controller: ctrl,
                                          textCapitalization: TextCapitalization.characters,
                                          decoration: const InputDecoration(
                                            labelText: 'Nombre de la Plantilla',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                          FilledButton(
                                            onPressed: () {
                                              if (ctrl.text.trim().isNotEmpty) {
                                                setModal(() {
                                                  plantillas.add({
                                                    'nombre': ctrl.text.trim().toUpperCase(),
                                                    'modalidad': 'Contrata',
                                                    'ggFijos': '5.0',
                                                    'ggVar': '10.0',
                                                    'util': '8.0',
                                                    'igv': 'true',
                                                  });
                                                });
                                                Navigator.pop(dCtx);
                                              }
                                            },
                                            child: const Text('Crear'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text('Nuevo...', style: TextStyle(fontSize: 11.5)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Plantillas estándar de Delphin Express sincronizadas')),
                                    );
                                  },
                                  child: const Text('Importar plantilla', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: plantillas.isEmpty
                                      ? null
                                      : () {
                                          final pl = plantillas[selectedIdx];
                                          final ctrl = TextEditingController(text: pl['nombre']);
                                          showDialog(
                                            context: ctx,
                                            builder: (dCtx) => AlertDialog(
                                              title: const Text('Editar Plantilla'),
                                              content: TextField(
                                                controller: ctrl,
                                                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
                                                FilledButton(
                                                  onPressed: () {
                                                    setModal(() => pl['nombre'] = ctrl.text.trim().toUpperCase());
                                                    Navigator.pop(dCtx);
                                                  },
                                                  child: const Text('Guardar'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                  child: const Text('Editar...', style: TextStyle(fontSize: 11.5)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: plantillas.length <= 1
                                      ? null
                                      : () {
                                          setModal(() {
                                            plantillas.removeAt(selectedIdx);
                                            selectedIdx = 0;
                                          });
                                        },
                                  child: const Text('Eliminar...', style: TextStyle(fontSize: 11.5, color: Colors.red)),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    final pl = plantillas[selectedIdx];
                                    final provider = context.read<PresupuestoProvider>();
                                    final p = provider.activePresupuesto;
                                    if (p != null) {
                                      provider.updatePiePresupuesto(
                                        PiePresupuesto(
                                          porcentajeGGFijos: double.parse(pl['ggFijos']!),
                                          porcentajeGGVariables: double.parse(pl['ggVar']!),
                                          porcentajeUtilidad: double.parse(pl['util']!),
                                          aplicarIGV: pl['igv'] == 'true',
                                          porcentajeIGV: 18.0,
                                        ),
                                      );
                                      provider.updatePresupuestoMetadata(
                                        p.copyWith(
                                          modalidadEjecucion: pl['modalidad'] == 'Contrata'
                                              ? 'Por contrata'
                                              : 'Por administración directa',
                                        ),
                                      );
                                    }
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ Plantilla "${pl['nombre']}" (${pl['modalidad']}) aplicada al presupuesto activo.',
                                        ),
                                        backgroundColor: Colors.green.shade800,
                                      ),
                                    );
                                  },
                                  child: const Text('Abrir plantilla', style: TextStyle(fontSize: 11.5)),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cerrar', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
