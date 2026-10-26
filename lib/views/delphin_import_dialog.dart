import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../providers/presupuesto_provider.dart';
import '../services/delphin_excel_service.dart';
import '../services/delphin_json_service.dart';
import '../services/delphin_sqlite_direct_service.dart';
import '../services/delphin_sqlite_service.dart';
import 'cloud_drive_screen.dart';

class DelphinImportDialog extends StatefulWidget {
  const DelphinImportDialog({super.key});

  @override
  State<DelphinImportDialog> createState() => _DelphinImportDialogState();
}

class _DelphinImportDialogState extends State<DelphinImportDialog> {
  bool _isLoading = false;
  String _statusMessage = '';
  final _jsonController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  static const List<Map<String, dynamic>> _delphinSamples = [
    {
      'title': 'Agua Potable y Saneamiento',
      'subtitle': '852 partidas con APUs | Redes, Tanques y Bombas | Lambayeque',
      'icon': Icons.water_drop_outlined,
      'color': Colors.blue,
      'asset': 'assets/delphin_projects/delphin_agua_potable.json',
    },
    {
      'title': 'Colegios e Infraestructura Educativa',
      'subtitle': '913 partidas con APUs | Aulas, Laboratorios y Cerco Perimétrico',
      'icon': Icons.school_outlined,
      'color': Colors.teal,
      'asset': 'assets/delphin_projects/delphin_colegios.json',
    },
    {
      'title': 'Carreteras y Pavimentación',
      'subtitle': '146 partidas con APUs | Asfalto, Base Granular y Movimiento Tierras',
      'icon': Icons.add_road_outlined,
      'color': Colors.orange,
      'asset': 'assets/delphin_projects/delphin_carreteras.json',
    },
    {
      'title': 'Hospital Categoría III',
      'subtitle': '1,630 partidas con APUs | Arquitectura, Instalaciones y Equipamiento',
      'icon': Icons.local_hospital_outlined,
      'color': Colors.redAccent,
      'asset': 'assets/delphin_projects/delphin_hospital_cat3.json',
    },
    {
      'title': 'Obras Hidráulicas y Riego',
      'subtitle': '643 partidas con APUs | Canales, Bocatomas y Desarenadores',
      'icon': Icons.waves_outlined,
      'color': Colors.cyan,
      'asset': 'assets/delphin_projects/delphin_obras_hidraulicas.json',
    },
    {
      'title': 'IOARR Plaza Bolognesi - Requena (Loreto)',
      'subtitle': '60 partidas con APUs | Rehabilitación Urbana',
      'icon': Icons.park_outlined,
      'color': Colors.green,
      'asset': 'assets/delphin_projects/delphin_requena_plaza.json',
    },
  ];

  Future<void> _importBundledDelphinProject(String assetPath, String projectName) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Cargando "$projectName" desde Delphin Express...';
      });

      final jsonString = await rootBundle.loadString(assetPath);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final presupuesto = DelphinJsonService.importDelphinJson(jsonMap);

      if (presupuesto == null) {
        throw Exception('No se pudo estructurar el presupuesto desde el archivo Delphin.');
      }

      if (!mounted) return;
      final provider = context.read<PresupuestoProvider>();
      await provider.importarPresupuestoExterno(presupuesto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Presupuesto "${presupuesto.name}" importado con éxito (${presupuesto.subpresupuestos.fold<int>(0, (prev, s) => prev + s.partidas.length)} partidas con APUs).'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar proyecto Delphin: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickSqliteFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Seleccionando base de datos SQLite (.sqlite / .db)...';
      });

      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      final file = files.first;
      final filePath = file.path;

      if (filePath == null || filePath.isEmpty) {
        throw Exception('No se pudo obtener la ruta local del archivo seleccionado.');
      }

      setState(() {
        _statusMessage = 'Leyendo catálogo de proyectos en SQLite...';
      });

      final projects = await DelphinSqliteDirectService.listProjects(filePath);

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (!mounted) return;

      if (projects.isEmpty) {
        throw Exception('No se encontraron tablas de proyectos de Delphin Express en este archivo SQLite.');
      }

      // Mostrar modal para seleccionar cuál de los proyectos importar
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.storage_rounded, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Proyectos en SQLite (${projects.length})', style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            height: 400,
            child: ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final p = projects[index];
                final pId = p['id_proyecto'] as String;
                final pNombre = p['nombre_proyecto'] as String? ?? 'Sin nombre';
                final pFecha = p['fecha_proyecto'] as String? ?? '';
                final pTipo = p['tipo_obra'] as String? ?? 'General';
                final pTotal = (p['total_proyecto'] as num?)?.toDouble() ?? 0.0;

                return ListTile(
                  dense: true,
                  title: Text(
                    pNombre,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Tipo: $pTipo | Fecha: $pFecha | Total: S/ ${pTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _isLoading = true;
                      _statusMessage = 'Extrayendo partidas y APUs de "$pNombre"...';
                    });

                    final extracted = await DelphinSqliteDirectService.extractProject(filePath, pId);

                    setState(() {
                      _isLoading = false;
                      _statusMessage = '';
                    });

                    if (extracted != null && mounted) {
                      await context.read<PresupuestoProvider>().importarPresupuestoExterno(extracted);
                      if (mounted) {
                        Navigator.pop(context, true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Presupuesto "${extracted.name}" importado con éxito desde SQLite.'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al leer SQLite: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickExcelFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Seleccionando archivo Excel de Delphin Express...';
      });

      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('No se pudieron leer los bytes del archivo seleccionado.');
      }

      setState(() {
        _statusMessage = 'Procesando cuadrícula y partidas de Delphin Express...';
      });

      final cleanName = file.name.replaceAll(RegExp(r'\.xlsx$|\.xls$', caseSensitive: false), '');
      final presupuesto = DelphinExcelService.importDelphinXlsx(bytes, defaultName: cleanName);

      if (presupuesto == null) {
        throw Exception('El archivo Excel no contiene una estructura válida de partidas.');
      }

      if (!mounted) return;
      final provider = context.read<PresupuestoProvider>();
      await provider.importarPresupuestoExterno(presupuesto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Presupuesto "${presupuesto.name}" importado con éxito desde Excel.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar Excel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickJsonFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Seleccionando archivo JSON...';
      });

      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('No se pudieron leer los bytes del archivo.');

      final jsonString = utf8.decode(bytes);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      final presupuesto = DelphinJsonService.importDelphinJson(jsonMap);
      if (presupuesto == null) {
        throw Exception('El formato JSON no coincide con el estándar de Delphin.');
      }

      if (!mounted) return;
      final provider = context.read<PresupuestoProvider>();
      await provider.importarPresupuestoExterno(presupuesto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Presupuesto "${presupuesto.name}" importado con éxito desde JSON.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar JSON: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importarTextoJson() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Procesando JSON pegado...';
      });

      final jsonMap = jsonDecode(text) as Map<String, dynamic>;
      final presupuesto = DelphinJsonService.importDelphinJson(jsonMap);

      if (presupuesto == null) {
        throw Exception('El JSON pegado no contiene la estructura requerida.');
      }

      if (!mounted) return;
      final provider = context.read<PresupuestoProvider>();
      await provider.importarPresupuestoExterno(presupuesto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Presupuesto "${presupuesto.name}" importado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en formato JSON: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openSqliteBrowser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Conectando con base de datos SQLDelphin_maestro.sqlite...';
    });

    final projects = await DelphinSqliteService.fetchLocalProjects();
    setState(() {
      _isLoading = false;
      _statusMessage = '';
    });

    if (!mounted) return;

    if (projects.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conexión con SQLDelphin'),
          content: const Text(
            'Para importar directo de SQLDelphin_maestro.sqlite sin pasar por Excel, ejecuta el microservicio backend local en tu PC (carpeta server/):\n\n'
            'cd server\n'
            'python -m uvicorn app:app --host 0.0.0.0 --port 8000',
            style: TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Proyectos en SQLDelphin (${projects.length})'),
        content: SizedBox(
          width: 480,
          height: 400,
          child: ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final p = projects[index];
              return ListTile(
                dense: true,
                title: Text(p['nombre'] ?? 'Sin nombre', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text('Tipo: ${p['tipo_obra']} | Fecha: ${p['fecha']}', style: const TextStyle(fontSize: 10)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    _isLoading = true;
                    _statusMessage = 'Importando ${p['nombre']}...';
                  });
                  final extracted = await DelphinSqliteService.extractProject(p['id']);
                  setState(() {
                    _isLoading = false;
                    _statusMessage = '';
                  });
                  if (extracted != null && mounted) {
                    await context.read<PresupuestoProvider>().importarPresupuestoExterno(extracted);
                    if (mounted) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Presupuesto "${extracted.name}" importado con éxito desde SQLDelphin.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.table_chart_outlined, color: Colors.teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Importar Delphin Express / Excel',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Importa la Hoja de Presupuesto, títulos, partidas, metrados y análisis de costos unitarios exportados desde Delphin Express BIM 360.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              if (_isLoading) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // SECCIÓN 1: PROYECTOS EMBLEMÁTICOS DE DELPHIN (1 TOQUE)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBDCEB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Proyectos Delphin Express (Listos en 1 Clic):',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          itemCount: _delphinSamples.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (ctx, idx) {
                            final sample = _delphinSamples[idx];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: (sample['color'] as Color).withOpacity(0.15),
                                child: Icon(sample['icon'] as IconData, size: 18, color: sample['color'] as Color),
                              ),
                              title: Text(
                                sample['title'] as String,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                sample['subtitle'] as String,
                                style: const TextStyle(fontSize: 10, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _importBundledDelphinProject(
                                  sample['asset'] as String,
                                  sample['title'] as String,
                                ),
                                child: const Text('Cargar', style: TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // SECCIÓN 2: IMPORTAR DESDE ARCHIVOS EXTERNOS
                const Text(
                  'O importa desde tus propios archivos:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),

                // Botón Google Drive
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CloudDriveScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_to_drive, color: Colors.white, size: 20),
                  label: const Text(
                    'Explorar en Google Drive / Nube',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),

                // Botón Excel .xlsx / .xls
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    foregroundColor: const Color(0xFF1B5E20),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _pickExcelFile,
                  icon: const Icon(Icons.file_present_rounded, color: Colors.green),
                  label: const Text(
                    'Seleccionar Archivo Excel (.xlsx / .xls)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),

                // Botón Seleccionar SQLite directo (.sqlite / .db)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _pickSqliteFile,
                  icon: const Icon(Icons.storage_rounded, color: Colors.amberAccent, size: 20),
                  label: const Text(
                    'Seleccionar Archivo SQLite (.sqlite / .db)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),

                // Botón JSON Delphin
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _pickJsonFile,
                  icon: const Icon(Icons.data_object, color: Colors.teal),
                  label: const Text('Seleccionar Archivo Delphin (.json)', style: TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(height: 8),

                // Botón Conectar SQLDelphin_maestro.sqlite
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openSqliteBrowser,
                  icon: const Icon(Icons.storage_rounded, color: Colors.amberAccent, size: 20),
                  label: const Text(
                    'Explorar Base SQLDelphin_maestro.sqlite (126 proyectos)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Pegar JSON
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.code, size: 18),
                  title: const Text('O pegar código JSON manualmente', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  children: [
                    TextField(
                      controller: _jsonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Pega aquí el código JSON del proyecto Delphin...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(10),
                      ),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _importarTextoJson,
                        child: const Text('Importar desde Texto'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
