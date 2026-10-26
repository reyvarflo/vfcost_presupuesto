import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/presupuesto.dart';
import '../providers/presupuesto_provider.dart';
import '../services/delphin_excel_service.dart';
import '../services/delphin_json_service.dart';
import '../services/ms_project_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/delphin_incidencia_panel.dart';
import '../widgets/partida_form_dialog.dart';
import 'cloud_drive_screen.dart';
import 'delphin_costos_unitarios_screen.dart';
import 'project_form_dialog.dart';
import 'resource_catalog_screen.dart';
import 'tabs/cronograma_tab.dart';
import 'tabs/formula_polinomica_tab.dart';
import 'tabs/hoja_presupuesto_tab.dart';
import 'tabs/pie_presupuesto_tab.dart';
import 'tabs/recursos_tab.dart';
import 'tabs/reportes_tab.dart';
import 'tabs/valorizaciones_tab.dart';

class PresupuestoDetailScreen extends StatefulWidget {
  final Presupuesto presupuesto;

  const PresupuestoDetailScreen({
    super.key,
    required this.presupuesto,
  });

  @override
  State<PresupuestoDetailScreen> createState() => _PresupuestoDetailScreenState();
}

class _PresupuestoDetailScreenState extends State<PresupuestoDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;
  bool _splitViewMode = false; // Modo Doble Panel (Split Screen) estilo Delphin Express
  bool _showBottomIncidenciaInSplit = true;

  final List<Widget> _tabs = const [
    HojaPresupuestoTab(),
    RecursosTab(),
    CronogramaTab(),
    ValorizacionesTab(),
    PiePresupuestoTab(),
    FormulaPolinomicaTab(),
    ReportesTab(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleProcesar() async {
    setState(() => _isProcessing = true);
    final provider = context.read<PresupuestoProvider>();
    await provider.procesarPresupuesto();
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('¡Presupuesto procesado exitosamente (F9 / Delphin)!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openAddPartidaDialog(BuildContext context, bool defaultIsTitle) {
    final provider = context.read<PresupuestoProvider>();
    final activeSub = provider.activeSubpresupuesto;
    if (activeSub == null) return;

    String suggested = '01';
    if (activeSub.partidas.isNotEmpty) {
      final last = activeSub.partidas.last;
      final parts = last.itemNumber.split('.');
      if (parts.isNotEmpty) {
        final lastNum = int.tryParse(parts.last) ?? 1;
        parts[parts.length - 1] = (lastNum + 1).toString().padLeft(2, '0');
        suggested = parts.join('.');
      }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final currentPresupuesto = provider.activePresupuesto ?? widget.presupuesto;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.architecture, color: Colors.amberAccent, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentPresupuesto.code} ${currentPresupuesto.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${currentPresupuesto.client} | ${currentPresupuesto.location}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Conmutador Vista Dividida (Split View)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              _splitViewMode ? Icons.tab : Icons.vertical_split_outlined,
              color: _splitViewMode ? Colors.amber.shade300 : Colors.white,
              size: 20,
            ),
            tooltip: _splitViewMode
                ? 'Volver a vista por pestañas'
                : 'Activar Vista Dividida Delphin (Partidas + Insumos + Incidencia)',
            onPressed: () {
              setState(() => _splitViewMode = !_splitViewMode);
            },
          ),
          // Botón PROCESAR (F9 en S10 / Delphin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade400,
                foregroundColor: Colors.black87,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(60, 32),
              ),
              onPressed: _isProcessing ? null : _handleProcesar,
              child: _isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate, size: 14),
                        SizedBox(width: 3),
                        Text('PROCESAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          // Menú de Impresión en PDF y Exportación Delphin / MS Project
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 270, maxWidth: 330),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            tooltip: 'Imprimir en PDF / Exportar Excel o MS Project',
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'pdf_all',
                child: Row(
                  children: [
                    Icon(Icons.print_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Todo el Expediente (PDF)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_presupuesto',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Hoja de Presupuesto (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_apu',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Costos Unitarios APUs (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_insumos',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Relación de Insumos (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_formula',
                child: Row(
                  children: [
                    Icon(Icons.functions, size: 18, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Fórmula Polinómica (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_cronograma',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Calendario Valorizado (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_metrados',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18, color: Colors.brown),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imprimir Metrados y Especif. (PDF)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exportar Delphin Excel (.xlsx)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'msproject',
                child: Row(
                  children: [
                    Icon(Icons.account_tree_outlined, size: 18, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exportar MS Project XML (.xml)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'json',
                child: Row(
                  children: [
                    Icon(Icons.data_object, size: 18, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exportar Delphin JSON',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'google_drive',
                child: Row(
                  children: [
                    Icon(Icons.add_to_drive, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guardar en Google Drive / Red',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              final sub = provider.activeSubpresupuesto;
              if (sub == null) return;
              if (val == 'pdf_all') {
                await PdfExportService.printExpedienteCompletoPdf(currentPresupuesto, sub);
              } else if (val == 'pdf_presupuesto') {
                await PdfExportService.printHojaPresupuesto(currentPresupuesto, sub);
              } else if (val == 'pdf_apu') {
                await PdfExportService.printApuReport(currentPresupuesto, sub);
              } else if (val == 'pdf_insumos') {
                await PdfExportService.printInsumosReport(currentPresupuesto, sub);
              } else if (val == 'pdf_formula') {
                await PdfExportService.printFormulaPolinomicaReport(currentPresupuesto, sub);
              } else if (val == 'pdf_cronograma') {
                await PdfExportService.printCronogramaReport(currentPresupuesto, sub);
              } else if (val == 'pdf_metrados') {
                await PdfExportService.printMetradosYEspecificacionesReport(currentPresupuesto, sub);
              } else if (val == 'excel') {
                await DelphinExcelService.exportDelphinXlsx(currentPresupuesto);
              } else if (val == 'msproject') {
                await MsProjectExportService.exportMsProjectXml(currentPresupuesto, sub);
              } else if (val == 'json') {
                await DelphinJsonService.exportDelphinJson(currentPresupuesto);
              } else if (val == 'google_drive') {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CloudDriveScreen(activePresupuesto: currentPresupuesto),
                  ),
                );
              }
            },
          ),
          // Menú de Más Herramientas (Catálogos y Configuración)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'Más Herramientas',
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delphin_catalog',
                child: Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Expanded(child: Text('Catálogo Maestro APUs (Delphin)')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 's10_catalog',
                child: Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Expanded(child: Text('Catálogo de Insumos (S10)')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cloud_drive',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Google Drive & Red')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(child: Text('Datos Generales del Proyecto')),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'delphin_catalog') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DelphinCostosUnitariosScreen()),
                );
              } else if (val == 's10_catalog') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResourceCatalogScreen()),
                );
              } else if (val == 'cloud_drive') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CloudDriveScreen(activePresupuesto: currentPresupuesto)),
                );
              } else if (val == 'settings') {
                showDialog(
                  context: context,
                  builder: (ctx) => ProjectFormDialog(
                    existingProject: currentPresupuesto,
                    onSave: (updated) {
                      provider.updatePresupuestoMetadata(updated);
                    },
                  ),
                );
              }
            },
          ),
        ],
        bottom: _splitViewMode
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.amber.shade300,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.account_tree_outlined, size: 20), text: 'Partidas'),
                  Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Insumos'),
                  Tab(icon: Icon(Icons.calendar_today_outlined, size: 20), text: 'Cronograma'),
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Valorizaciones'),
                  Tab(icon: Icon(Icons.pie_chart_outline, size: 20), text: 'Pie / GG'),
                  Tab(icon: Icon(Icons.functions, size: 20), text: 'F. Polinómica'),
                  Tab(icon: Icon(Icons.print_outlined, size: 20), text: 'Reportes'),
                ],
              ),
      ),
      body: _splitViewMode
          ? _buildDelphinSplitWorkspace(currentPresupuesto)
          : TabBarView(
              controller: _tabController,
              children: _tabs,
            ),
      floatingActionButton: (!_splitViewMode && _tabController.index == 0)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_title',
                  tooltip: 'Nuevo Título',
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  onPressed: () => _openAddPartidaDialog(context, true),
                  child: const Icon(Icons.title),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'fab_partida',
                  tooltip: 'Nueva Partida (APU)',
                  onPressed: () => _openAddPartidaDialog(context, false),
                  icon: const Icon(Icons.add),
                  label: const Text('Partida'),
                ),
              ],
            )
          : null,
    );
  }

  /// Espacio de Trabajo Dividido idéntico a la interfaz de escritorio de Delphin Express BIM 360:
  /// - Izquierda Arriba: Hoja de Presupuesto (Árbol WBS)
  /// - Izquierda Abajo: Gráfico "Incidencia de Costos" + Tabla "PIE RESUMEN ÚNICO POR PROYECTO"
  /// - Derecha: Lista de Insumos del Presupuesto / Proyecto agrupada por categorías
  Widget _buildDelphinSplitWorkspace(Presupuesto currentPresupuesto) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = constraints.maxWidth >= 700;

        final leftColumn = Column(
          children: [
            const Expanded(
              flex: 6,
              child: HojaPresupuestoTab(),
            ),
            // Barra para mostrar/ocultar el panel inferior de Incidencia y Pie Resumen
            InkWell(
              onTap: () => setState(() => _showBottomIncidenciaInSplit = !_showBottomIncidenciaInSplit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: const Color(0xFF1E3A8A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart, size: 15, color: Colors.amber),
                        SizedBox(width: 6),
                        Text(
                          'Incidencia de Costos y Pie Resumen Único (Delphin)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Icon(
                      _showBottomIncidenciaInSplit ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            if (_showBottomIncidenciaInSplit)
              SizedBox(
                height: 245,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  child: DelphinIncidenciaPanel(
                    presupuesto: currentPresupuesto,
                    compact: true,
                  ),
                ),
              ),
          ],
        );

        if (isHorizontal) {
          return Row(
            children: [
              Expanded(flex: 11, child: leftColumn),
              Container(width: 2, color: const Color(0xFF94A3B8)),
              const Expanded(flex: 10, child: RecursosTab()),
            ],
          );
        } else {
          // En pantalla vertical estrecha apila Arriba (Partidas + Incidencia) y Abajo (Insumos)
          return Column(
            children: [
              Expanded(flex: 6, child: leftColumn),
              Container(height: 2, color: const Color(0xFF94A3B8)),
              const Expanded(flex: 5, child: RecursosTab()),
            ],
          );
        }
      },
    );
  }
}
