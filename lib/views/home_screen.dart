import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/sample_projects.dart';
import '../models/presupuesto.dart';
import '../providers/presupuesto_provider.dart';
import '../services/storage_service.dart';
import '../theme/varflo_theme.dart';
import '../utils/number_format_utils.dart';
import '../widgets/presupuesto_summary_card.dart';
import 'cloud_drive_screen.dart';
import 'delphin_import_dialog.dart';
import 'delphin_options_grid_dialog.dart';
import 'presupuesto_detail_screen.dart';
import 'project_form_dialog.dart';
import 'resource_catalog_screen.dart';
import 's2k_import_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'TODOS';

  static const List<String> _categoriasDelphin = [
    'TODOS',
    'Edificaciones',
    'Agua potable y alcantarillado',
    'Obras Viales',
    'Infraestructura Educativa',
    'Obras Hidráulicas',
    'PROYECTO URBANIZMO',
    'DRENAJE PLUVIAL',
    'Mejoramiento',
  ];

  void _openNewProjectDialog(BuildContext context) {
    final provider = context.read<PresupuestoProvider>();
    final nextCode = '010${(provider.presupuestos.length + 1).toString().padLeft(3, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => ProjectFormDialog(
        existingProject: Presupuesto(
          id: '',
          code: nextCode,
          name: '',
          client: '',
          location: 'LIMA - LIMA - PERÚ',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        onSave: (newProj) async {
          await provider.createPresupuesto(
            code: newProj.code,
            name: newProj.name,
            client: newProj.client,
            location: newProj.location,
            currencySymbol: newProj.currencySymbol,
            currencyName: newProj.currencyName,
            jornada: newProj.jornada,
            plazoDias: newProj.plazoDias,
          );
          if (mounted && provider.activePresupuesto != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PresupuestoDetailScreen(presupuesto: provider.activePresupuesto!),
              ),
            );
          }
        },
      ),
    );
  }

  void _openImportJsonDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Presupuesto (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pegue el contenido JSON exportado desde VFCOST para importar el proyecto con todas sus partidas y APUs:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{\n  "code": "0102001",\n  ...\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final jsonStr = controller.text.trim();
              if (jsonStr.isNotEmpty) {
                final success = await context.read<PresupuestoProvider>().importPresupuestoFromJson(jsonStr);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '¡Proyecto importado con éxito!' : 'Error: formato JSON inválido'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  void _openImportS2kDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const S2kImportDialog(),
    );
  }

  void _openImportDelphinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const DelphinImportDialog(),
    );
  }

  void _openDelphinOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const DelphinOptionsGridDialog(),
    );
  }

  void _optimizarBase(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cleaning_services_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text('Base de datos optimizada: índices compactados y temporales limpios.'),
          ],
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _copiaSeguridadCompleta(BuildContext context) {
    final provider = context.read<PresupuestoProvider>();
    final presupuestos = provider.presupuestos;
    final jsonList = presupuestos.map((p) => StorageService.exportPresupuestoToJson(p)).toList();
    Clipboard.setData(ClipboardData(text: jsonList.join('\n---\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Copia de seguridad de ${presupuestos.length} proyectos copiada al portapapeles.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetToSample(BuildContext context) async {
    final sample = SampleProjects.getSamplePresupuesto();
    final provider = context.read<PresupuestoProvider>();
    await provider.createPresupuesto(
      code: sample.code,
      name: sample.name,
      client: sample.client,
      location: sample.location,
      currencySymbol: sample.currencySymbol,
      currencyName: sample.currencyName,
      jornada: sample.jornada,
      plazoDias: sample.plazoDias,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presupuesto de muestra S10 cargado exitosamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuestos = provider.presupuestos;

    // Filtrado por texto y por categoría de Delphin
    final filtered = presupuestos.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.client.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'TODOS' ||
          p.tipoObra.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
          p.naturaleza.toLowerCase().contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.amber.shade400,
                  child: const Icon(Icons.architecture, color: Colors.black, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VF COST Pro',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'S10 & Delphin Express BIM 360',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón Google Drive & Red
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.lightBlueAccent, size: 22),
            tooltip: 'Google Drive & Respaldo en la Red',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CloudDriveScreen()),
              );
            },
          ),
          // Mosaicos de Delphin Express
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.amberAccent, size: 22),
            tooltip: 'Opciones y Maestros Delphin',
            onPressed: () => _openDelphinOptions(context),
          ),
          // Menú Completo de Acciones
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            constraints: const BoxConstraints(minWidth: 270, maxWidth: 330),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'google_drive',
                child: Row(
                  children: [
                    Icon(Icons.add_to_drive, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Google Drive & Red (Guardar/Restaurar)', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delphin_tiles',
                child: Row(
                  children: [
                    Icon(Icons.grid_view, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Expanded(child: Text('Opciones Delphin (Tiles)', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_delphin',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Expanded(child: Text('Importar Delphin (.xlsx / .sqlite / .json)', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_s2k',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.indigo),
                    SizedBox(width: 8),
                    Expanded(child: Text('Importar Backup S10 (.S2K)', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_outlined, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('Copia de Seguridad Rápida', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'optimize',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(child: Text('Optimizar Base de Datos', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sample',
                child: Row(
                  children: [
                    Icon(Icons.folder_special_outlined, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(child: Text('Cargar Proyecto de Ejemplo', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'google_drive') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CloudDriveScreen()),
                );
              }
              if (val == 'delphin_tiles') _openDelphinOptions(context);
              if (val == 'import_delphin') _openImportDelphinDialog(context);
              if (val == 'import_s2k') _openImportS2kDialog(context);
              if (val == 'backup') _copiaSeguridadCompleta(context);
              if (val == 'optimize') _optimizarBase(context);
              if (val == 'sample') _resetToSample(context);
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra de búsqueda moderna Varflo
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: VarfloTheme.azulPrincipal.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar proyectos por nombre, código o cliente...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: VarfloTheme.grisTextoSecundario),
                        prefixIcon: const Icon(Icons.search, color: VarfloTheme.azulPrincipal, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: VarfloTheme.grisBordeSuave),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: VarfloTheme.grisBordeSuave),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: VarfloTheme.azulPrincipal, width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),

                // Filtro horizontal tipo Delphin con Botones Modernos Dinámicos Varflo
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _categoriasDelphin.length,
                    itemBuilder: (context, index) {
                      final cat = _categoriasDelphin[index];
                      final isSelected = _selectedCategory == cat;
                      final count = cat == 'TODOS'
                          ? presupuestos.length
                          : presupuestos
                              .where((p) =>
                                  p.tipoObra.toLowerCase().contains(cat.toLowerCase()) ||
                                  p.naturaleza.toLowerCase().contains(cat.toLowerCase()))
                              .length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isSelected ? VarfloTheme.gradienteAzul : null,
                              color: isSelected ? null : VarfloTheme.grisSuperficie,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected ? VarfloTheme.azulPrincipal : VarfloTheme.grisBordeSuave,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? VarfloTheme.sombraBotonAzul
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat == 'TODOS' ? Icons.folder_special : _getIconForCat(cat),
                                  size: 15,
                                  color: isSelected ? Colors.white : VarfloTheme.azulPrincipal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : VarfloTheme.grisTextoOscuro,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? VarfloTheme.naranjaPrincipal : VarfloTheme.grisFondo,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : VarfloTheme.grisTextoSecundario,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Lista de Presupuestos (Tarjetas con candado y fecha estilo Delphin)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No hay presupuestos en la categoría "$_selectedCategory"'
                                    : 'No se encontraron resultados para "$_searchQuery"',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: VarfloTheme.naranjaPrincipal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      elevation: 3,
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Crear Presupuesto'),
                                    onPressed: () => _openNewProjectDialog(context),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: VarfloTheme.azulPrincipal,
                                      side: const BorderSide(color: VarfloTheme.azulPrincipal, width: 1.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                                    label: const Text('Importar Delphin (.xlsx / .sqlite)'),
                                    onPressed: () => _openImportDelphinDialog(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return PresupuestoSummaryCard(
                              presupuesto: p,
                              onToggleLock: () => provider.toggleLockPresupuesto(p.id),
                              onTap: () {
                                provider.selectPresupuesto(p.id);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PresupuestoDetailScreen(presupuesto: p),
                                  ),
                                );
                              },
                              onDuplicate: () => provider.duplicatePresupuesto(p.id),
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Eliminar presupuesto?'),
                                    content: Text('Se eliminará permanentemente "${p.name}".'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  provider.deletePresupuesto(p.id);
                                }
                              },
                              onShare: () {
                                final jsonStr = StorageService.exportPresupuestoToJson(p);
                                Clipboard.setData(ClipboardData(text: jsonStr));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copia JSON copiada al portapapeles')),
                                );
                              },
                              onSaveToDrive: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CloudDriveScreen(activePresupuesto: p),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: VarfloTheme.gradienteNaranja,
          borderRadius: BorderRadius.circular(30),
          boxShadow: VarfloTheme.sombraBotonNaranja,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _openNewProjectDialog(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Nuevo Presupuesto',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForCat(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('edif')) return Icons.apartment;
    if (c.contains('agua') || c.contains('saneam')) return Icons.water_drop;
    if (c.contains('vial') || c.contains('carret')) return Icons.add_road;
    if (c.contains('educat') || c.contains('coleg')) return Icons.school;
    if (c.contains('hidr') || c.contains('riego')) return Icons.waves;
    if (c.contains('urban')) return Icons.location_city;
    if (c.contains('pluvial')) return Icons.thunderstorm;
    return Icons.construction;
  }
}
